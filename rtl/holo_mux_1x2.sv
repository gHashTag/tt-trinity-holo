// SPDX-License-Identifier: Apache-2.0
// holo_mux_1x2.sv — 2:1 holographic multiplexer with 1-cycle pipeline register
//
// L-DPC24 Lane Y · tt-trinity-holo · TTSKY26c (multi-die)
// Hypothesis H₉: TOPS/W ≥ 2000 on 1×2 HOLOGRAPHIC tile
// Anchor: φ²+φ⁻²=3   DOI 10.5281/zenodo.19227877
//
// Author: Vasilev Dmitrii <admin@t27.ai>
//
// Description:
//   Parameterisable 2:1 mux selecting between two die outputs (die A / die B)
//   for the 1×2 multi-die HOLOGRAPHIC mesh. A 1-cycle pipeline register
//   absorbs cross-die combinatorial slack before output.
//
//   R-SI-1: zero new `*` operators in synthesisable RTL — this module is
//   purely mux/register, no multiply.
//   R15: NO mutation of R-marker cell values in RTL.

`default_nettype none

module holo_mux_1x2 #(
    parameter int unsigned WIDTH = 64  // hypervector slot width; default 64 bits
) (
    input  logic             clk,
    input  logic             rst_n,  // active-low synchronous reset
    input  logic [WIDTH-1:0] die_a,  // input from die A
    input  logic [WIDTH-1:0] die_b,  // input from die B
    input  logic             sel,    // 0 → die_a, 1 → die_b
    output logic [WIDTH-1:0] dout    // registered mux output (1-cycle latency)
);

    // -------------------------------------------------------------------------
    // Stage 0: combinatorial selection
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] mux_out;
    always_comb begin
        mux_out = sel ? die_b : die_a;
    end

    // -------------------------------------------------------------------------
    // Stage 1: pipeline register (absorbs cross-die fanout slack)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dout <= {WIDTH{1'b0}};
        end else begin
            dout <= mux_out;
        end
    end

endmodule

`default_nettype wire
