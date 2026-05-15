// =============================================================================
// holo_razor_ff.sv — Razor Flip-Flop with Shadow Sampling & Error Detection
// TTSKY26c HOLOGRAPHIC SKU · L-DPC24 Lane B'
// =============================================================================
// Description:
//   Stand-alone SystemVerilog cell implementing the Razor flip-flop scheme.
//   A main flop captures data on the rising edge; a shadow flop captures on
//   the falling edge.  A combinational comparator drives error_out high when
//   the two outputs disagree, indicating a metastability / timing violation.
//
// R-SI-1 compliance: no '*' operator is used anywhere in this file.
// =============================================================================

`default_nettype none

module holo_razor_ff #(
    parameter int W = 32
) (
    input  logic          clk,
    input  logic          rst_n,
    input  logic [W-1:0]  d,
    output logic [W-1:0]  q,          // main flop — rising-edge
    output logic [W-1:0]  q_shadow,   // shadow flop — falling-edge
    output logic          error_out   // = |(q ^ q_shadow)
);

    // -------------------------------------------------------------------------
    // Main flip-flop: rising-edge, synchronous active-low reset
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n)
            q <= {W{1'b0}};
        else
            q <= d;
    end

    // -------------------------------------------------------------------------
    // Shadow flip-flop: falling-edge, synchronous active-low reset
    // -------------------------------------------------------------------------
    always_ff @(negedge clk) begin
        if (!rst_n)
            q_shadow <= {W{1'b0}};
        else
            q_shadow <= d;
    end

    // -------------------------------------------------------------------------
    // Error detection: any bit mismatch between q and q_shadow
    // -------------------------------------------------------------------------
    logic [W-1:0] xor_vec;
    assign xor_vec  = q ^ q_shadow;
    assign error_out = |xor_vec;

endmodule

`default_nettype wire

// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
