// =============================================================================
// shift_add_baseline.sv  —  MAC-free Shift-Add Reference PE
// Wave-29 Lane E · L-DPC26 · tt-trinity-holo
// =============================================================================
//
// Purpose:
//   Minimal reference Processing Element using only shifts and additions
//   (zero multiply operators, R-SI-1 compliant).  Provides the energy/op
//   baseline against which holo_lut_pe (PR #19, 91c164ac) is compared.
//
// Function:
//   Computes an 8-bit hash of (addr, data_in) using shift-and-add mixing:
//
//     stage1 = data_in ^ (data_in >> 3) ^ (data_in >> 5)
//     stage2 = stage1 + addr[3:0] extended to 8 bits
//     stage3 = stage2 ^ (stage2 >> 1)
//     data_out = stage3 (registered, 1-cycle pipeline)
//
//   This represents the switching-activity cost of a typical shift-add
//   arithmetic pipeline — the architectural class that LUT-based PEs aim
//   to beat in energy/op.
//
// Hard Rules:
//   R-SI-1  : ZERO * operator anywhere in this file
//   R5-HONEST : 🟡 SIM verdict — no silicon measurement yet
//   R18     : Additive only — does not touch any existing RTL
//
// Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877
// ONE SHOT: gHashTag/trinity-fpga#108
//
// Refs #108
// Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module shift_add_baseline #(
    parameter int unsigned ADDR_WIDTH = 4,
    parameter int unsigned DATA_WIDTH = 8
) (
    input  wire                      clk,
    input  wire                      rst_n,

    input  wire                      valid_in,
    input  wire [ADDR_WIDTH-1:0]     addr,
    input  wire [DATA_WIDTH-1:0]     data_in,

    output logic                     valid_out,
    output logic [DATA_WIDTH-1:0]    data_out
);

    // -------------------------------------------------------------------------
    // Combinational shift-add hash pipeline (NO * operators)
    // -------------------------------------------------------------------------

    // Stage 1: XOR folding via right shifts
    logic [DATA_WIDTH-1:0] stage1;
    always_comb begin
        stage1 = data_in
               ^ (data_in >> 3)   // pure shift
               ^ (data_in >> 5);  // pure shift
    end

    // Stage 2: Add the zero-extended address to mix in spatial information
    // addr is ADDR_WIDTH bits; zero-extend to DATA_WIDTH for addition
    logic [DATA_WIDTH-1:0] addr_ext;
    always_comb begin
        addr_ext = {{(DATA_WIDTH - ADDR_WIDTH){1'b0}}, addr};
    end

    logic [DATA_WIDTH-1:0] stage2;
    always_comb begin
        // Addition (not multiplication) — R-SI-1 compliant
        stage2 = stage1 + addr_ext;
    end

    // Stage 3: Final avalanche via shift-XOR
    logic [DATA_WIDTH-1:0] stage3;
    always_comb begin
        stage3 = stage2 ^ (stage2 >> 1);  // pure shift
    end

    // -------------------------------------------------------------------------
    // 1-cycle registered output (matches holo_lut_pe pipeline depth)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            data_out  <= '0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                data_out <= stage3;
            end else begin
                data_out <= '0;
            end
        end
    end

endmodule

`default_nettype wire
