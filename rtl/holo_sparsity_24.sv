// =============================================================================
// holo_sparsity_24.sv  —  2:4 Structured Sparsity Decoder
// Lane S · L-DPC26 Wave-29 · TRI-27 dataflow extension
// =============================================================================
//
// Extends Lane V Platinum LUT PE (PR #19, commit 91c164ac) with sparse-input
// support. This module is a WRAPPER-EXTERNAL addition: holo_lut_pe.sv is NOT
// modified (R18 LAYER-FROZEN).
//
// Specification:
//   - Input: 4-element ternary group (8 bits total, 2 bits per element)
//     Encoding: 2'b00 = zero, 2'b01 = +1, 2'b10 = -1, 2'b11 = reserved
//   - Sparsity format: 2:4 — exactly 2 non-zero elements out of 4
//   - Compressed form: 4-bit mask (one-hot pair) + 2-element payload (4 bits)
//   - Decoder: reconstructs dense 4-element vector via pure XOR + mux (no *)
//   - Output: dense 4-element vector (8 bits, 2 bits per element)
//
// R-rules:
//   R-SI-1  : ZERO * operator — all decode via XOR / mux / shift / AND
//   R18     : holo_lut_pe.sv untouched; this file wraps externally
//   R5      : PROJECTION — sim-derived TOPS gain (no silicon measurement yet)
//
// 2:4 mask encoding (4-bit mask, popcount must equal 2):
//   mask[3:0] — bit i = 1 means element i is non-zero
//   Valid masks (C(4,2)=6): 4'b0011, 4'b0101, 4'b0110, 4'b1001, 4'b1010, 4'b1100
//
// Payload encoding:
//   payload[1:0] → compressed non-zero element 0 (2-bit ternary)
//   payload[3:2] → compressed non-zero element 1 (2-bit ternary)
//
// Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877
// ONE SHOT: https://github.com/gHashTag/trinity-fpga/issues/108
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

// SPDX-License-Identifier: Apache-2.0

module holo_sparsity_24 (
    input  wire        clk,
    input  wire        rst_n,

    // -------------------------------------------------------------------------
    // Compressed sparse input interface
    // -------------------------------------------------------------------------
    input  wire        valid_in,          // strobe: compressed input is valid
    input  wire [3:0]  mask_in,           // 4-bit 2:4 mask, popcount must = 2
    input  wire [3:0]  payload_in,        // 2-element compressed payload (2b each)

    // -------------------------------------------------------------------------
    // Dense reconstructed output interface
    // -------------------------------------------------------------------------
    output logic       valid_out,         // one cycle after valid_in (registered)
    output logic       mask_err,          // asserted when popcount(mask_in) != 2
    output logic [7:0] dense_out          // 4-element ternary vector (2b each)
                                          // dense_out[1:0]  = element 0
                                          // dense_out[3:2]  = element 1
                                          // dense_out[5:4]  = element 2
                                          // dense_out[7:6]  = element 3
);

    // -------------------------------------------------------------------------
    // Popcount of 4-bit mask — pure AND/XOR/add, zero * operators
    // popcount4(m) = m[0] + m[1] + m[2] + m[3]
    // Implemented as two 2-bit partial sums XOR-reduced to 3-bit result
    // -------------------------------------------------------------------------
    function automatic [2:0] popcount4(input [3:0] m);
        logic [1:0] lo, hi;
        logic [2:0] pc;
        lo = {1'b0, m[0]} + {1'b0, m[1]};  // 2-bit: 0,1,2
        hi = {1'b0, m[2]} + {1'b0, m[3]};  // 2-bit: 0,1,2
        pc = {1'b0, lo} + {1'b0, hi};       // 3-bit: 0..4
        return pc;
    endfunction

    // -------------------------------------------------------------------------
    // Mask validity check: popcount must be exactly 2
    // -------------------------------------------------------------------------
    logic mask_valid;
    always_comb begin
        mask_valid = (popcount4(mask_in) == 3'd2);
    end

    // -------------------------------------------------------------------------
    // Priority encoder: find position of 1st and 2nd set bit in mask
    // Used to determine which elements receive the payload values.
    // Implemented via cascaded conditional (no * or division).
    //
    // nz_pos0: position (0-3) of the first (LSB-first) non-zero element
    // nz_pos1: position (0-3) of the second non-zero element
    // -------------------------------------------------------------------------
    logic [1:0] nz_pos0, nz_pos1;

    always_comb begin
        // Default safe values (overridden below when mask_valid)
        nz_pos0 = 2'd0;
        nz_pos1 = 2'd1;

        if (mask_valid) begin
            // Find first set bit (LSB-first)
            if      (mask_in[0]) nz_pos0 = 2'd0;
            else if (mask_in[1]) nz_pos0 = 2'd1;
            else if (mask_in[2]) nz_pos0 = 2'd2;
            else                 nz_pos0 = 2'd3;

            // Find second set bit (next after first)
            // Six valid masks; encode directly:
            case (mask_in)
                4'b0011: begin nz_pos0 = 2'd0; nz_pos1 = 2'd1; end
                4'b0101: begin nz_pos0 = 2'd0; nz_pos1 = 2'd2; end
                4'b0110: begin nz_pos0 = 2'd1; nz_pos1 = 2'd2; end
                4'b1001: begin nz_pos0 = 2'd0; nz_pos1 = 2'd3; end
                4'b1010: begin nz_pos0 = 2'd1; nz_pos1 = 2'd3; end
                4'b1100: begin nz_pos0 = 2'd2; nz_pos1 = 2'd3; end
                default: begin nz_pos0 = 2'd0; nz_pos1 = 2'd1; end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Decode payload into 2-bit ternary values for non-zero positions
    // payload[1:0] → nz_val0 (first non-zero element)
    // payload[3:2] → nz_val1 (second non-zero element)
    // -------------------------------------------------------------------------
    logic [1:0] nz_val0, nz_val1;
    always_comb begin
        nz_val0 = payload_in[1:0];
        nz_val1 = payload_in[3:2];
    end

    // -------------------------------------------------------------------------
    // Dense vector reconstruction via mux (no * operator)
    // For each of the 4 output positions, select:
    //   - nz_val0 if position == nz_pos0
    //   - nz_val1 if position == nz_pos1
    //   - 2'b00   (zero) otherwise
    // -------------------------------------------------------------------------
    logic [1:0] dense_comb [0:3];

    always_comb begin
        integer idx;
        for (idx = 0; idx < 4; idx = idx + 1) begin
            if (mask_valid) begin
                if (nz_pos0 == idx[1:0])
                    dense_comb[idx] = nz_val0;
                else if (nz_pos1 == idx[1:0])
                    dense_comb[idx] = nz_val1;
                else
                    dense_comb[idx] = 2'b00;
            end else begin
                dense_comb[idx] = 2'b00;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Output register — 1-cycle pipeline
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            mask_err  <= 1'b0;
            dense_out <= 8'h00;
        end else begin
            valid_out <= valid_in;
            mask_err  <= valid_in & ~mask_valid;
            if (valid_in) begin
                // Concatenate the four 2-bit elements into an 8-bit bus
                // No * operator: direct concatenation via {} (structural)
                dense_out <= {dense_comb[3], dense_comb[2],
                              dense_comb[1], dense_comb[0]};
            end else begin
                dense_out <= 8'h00;
            end
        end
    end

endmodule

`default_nettype wire

// =============================================================================
// R-SI-1 star-free proof manifest
// grep -n '\*' rtl/holo_sparsity_24.sv → zero operator-context matches
// (comment lines and string literals with '*' are not arithmetic operators)
//
// Operators used: +, ^, &, |, ~, ==, !=, {}, >>, <<, []
// NO multiplication operator (*) anywhere in synthesisable logic.
//
// Wave-29 Lane S · Refs #108
// Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
// =============================================================================
