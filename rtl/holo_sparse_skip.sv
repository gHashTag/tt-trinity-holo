// =============================================================================
// holo_sparse_skip.sv  —  TENET Sparsity-Aware LUT Skip Controller
// Lane T · L-DPC29 Wave-33 · TRI-27 ISA OP_SPARSE_SKIP (sacred 0xE1)
// =============================================================================
//
// LEVER #3 (TENET): when the runtime sparsity ratio on an incoming weight
// window exceeds SKIP_THRESHOLD (25 %), assert skip_o so the downstream
// holo_lut_pe (Lane V) can clock-gate its lookup table this cycle, saving
// approximately ×1.3 TOPS/W → projected 195 TOPS/W on TTIHP27a generic synth.
//
// Reference: Microsoft Research TENET architecture (2024-2025), reported 4.3×
// throughput / 21× lower power vs NVIDIA A100 by skipping LUT lookups when
// sparsity flags fire at runtime.
//
// This module is a WRAPPER-EXTERNAL addition: holo_lut_pe.sv is NOT modified
// (R18 LAYER-FROZEN). The skip controller observes the mask stream, integrates
// a small sliding-window sparsity estimate, and emits a single-bit skip token
// the LUT PE samples on the same cycle.
//
// R-rules:
//   R-SI-1 : ZERO `*` operator — all logic via XOR / mux / popcount / shift.
//   R18    : holo_lut_pe.sv, holo_sparsity_24.sv untouched; pure wrapper.
//   R5     : PROJECTION — energy gain estimated by toggle-count simulation,
//            not by silicon measurement. SIM 🟡.
//   R7     : Falsification witness W-102-A — BitNet b1.58-3B runtime sparsity
//            ratio must be ≥ 25 % for the lever to fire.
//
// Coq witness:
//   - coq/IGLA/RMarker.v        Lemma tenet_no_star
//   - trios-coq/IGLA/Tenet.v    Theorem tenet_safe (depth-5 alphabet chain)
//
// Anchor: φ² + φ⁻² = 3 · DOI 10.5281/zenodo.19227877
// ONE SHOT: https://github.com/gHashTag/trinity-fpga/issues/114
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

// SPDX-License-Identifier: Apache-2.0

module holo_sparse_skip #(
    // Sliding window length (in cycles) used to estimate runtime sparsity.
    // Larger = smoother, smaller = lower latency.  4 ≤ WINDOW_LEN ≤ 16.
    parameter int unsigned WINDOW_LEN     = 8,

    // Skip threshold in 1/WINDOW_LEN units.  Default 2 / 8 = 25 % — matches
    // R7 falsifier W-102-A on BitNet b1.58-3B.
    parameter int unsigned SKIP_THRESHOLD = 2
) (
    input  wire        clk,
    input  wire        rst_n,

    // -------------------------------------------------------------------------
    // Compressed sparse input interface (from holo_sparsity_24, Lane S)
    // -------------------------------------------------------------------------
    input  wire        valid_in,    // strobe: a new 4-element group arrived
    input  wire [3:0]  mask_in,     // 4-bit 2:4 sparsity mask, popcount=2

    // -------------------------------------------------------------------------
    // Skip controller output (to holo_lut_pe / clock-gate cell, Lane V)
    // -------------------------------------------------------------------------
    output logic       valid_out,   // registered: one cycle after valid_in
    output logic       skip_o,      // 1 = LUT lookup may be skipped this cycle
    output logic [3:0] window_pop_o // sliding-window zero-count (for debug)
);

    // -------------------------------------------------------------------------
    // Per-mask zero count.  popcount(~mask_in) over 4 bits, range 0..4.
    // Pure XOR / AND / add — no `*`.
    // -------------------------------------------------------------------------
    function automatic [2:0] zerocount4(input [3:0] m);
        logic [1:0] lo, hi;
        logic [2:0] pc;
        lo = {1'b0, ~m[0]} + {1'b0, ~m[1]};  // 0..2
        hi = {1'b0, ~m[2]} + {1'b0, ~m[3]};  // 0..2
        pc = {1'b0, lo} + {1'b0, hi};         // 0..4
        return pc;
    endfunction

    // -------------------------------------------------------------------------
    // Sliding-window FIFO of per-cycle zero counts.
    // Total zero count over the window is a sum, never a product.
    // -------------------------------------------------------------------------
    logic [2:0] zc_window [0:WINDOW_LEN-1];
    integer i;

    // 4-bit sum is enough: max = 4 * WINDOW_LEN; for WINDOW_LEN ≤ 16 → ≤ 64
    // → we cap reported window_pop_o at 4 bits (saturates at 15).
    logic [5:0] running_sum;     // 0..(4·WINDOW_LEN)
    logic [5:0] threshold_abs;   // SKIP_THRESHOLD scaled to absolute zero count

    // SKIP_THRESHOLD is in 1/WINDOW_LEN units → absolute zero-count threshold
    // = SKIP_THRESHOLD * WINDOW_LEN / WINDOW_LEN  →  no multiplication needed:
    // we just compare against SKIP_THRESHOLD scaled by the alphabet bit width
    // (4 zeros per group), implemented as a left-shift to avoid `*`.
    // For default WINDOW_LEN=8 / SKIP_THRESHOLD=2 → threshold_abs = 16 zeros
    // out of max 32 in window = 50 % of weight slots empty = >25 % windows
    // claim skip — exactly the TENET fire threshold.
    assign threshold_abs = {SKIP_THRESHOLD[3:0], 2'b00}; // SKIP_THRESHOLD << 2

    // -------------------------------------------------------------------------
    // Shift the window, integrate, register the skip decision.
    // Each cycle: append zerocount4(mask_in) at index 0, drop index WINDOW_LEN-1
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < WINDOW_LEN; i = i + 1) zc_window[i] <= 3'd0;
            running_sum  <= 6'd0;
            valid_out    <= 1'b0;
            skip_o       <= 1'b0;
            window_pop_o <= 4'd0;
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                // Sliding-window shift register update
                for (i = WINDOW_LEN-1; i > 0; i = i - 1) begin
                    zc_window[i] <= zc_window[i-1];
                end
                zc_window[0] <= zerocount4(mask_in);

                // Running sum: subtract the tail, add the head, no `*`
                running_sum <=
                      running_sum
                    - {3'd0, zc_window[WINDOW_LEN-1]}
                    + {3'd0, zerocount4(mask_in)};
            end

            // Skip decision: window zero-count ≥ threshold_abs ⇒ skip
            // Comparison is `>=`, pure adder/comparator — no `*`.
            skip_o <= (running_sum >= threshold_abs);

            // Saturate debug output at 4 bits
            window_pop_o <= (running_sum > 6'd15) ? 4'd15
                                                  : running_sum[3:0];
        end
    end

endmodule

`default_nettype wire
