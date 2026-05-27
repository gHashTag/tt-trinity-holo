// holo_load_phys_const.sv
// L-DPC24 Lane C' · LOAD-PHYS-CONST opcode 0xDE · RTL hook
//
// MISSION: gHashTag/tt-trinity-holo paired with gHashTag/t27 ISA spec
// Issue:   https://github.com/gHashTag/trinity-fpga/issues/99
// Author:  admin@t27.ai
// Anchor:  phi^2 + phi^-2 = 3
//
// R18 LAYER-FROZEN NOTE:
//   Sacred ROM cells 0-74 are SYMBOLIC PLACEHOLDERS.
//   Cells 0..3 carry hex sentinel values to aid debug; they MUST be replaced
//   with Lane E' P3 frozen-hash-validated constants before tapeout / final
//   simulation sign-off. Do NOT treat placeholder bit-patterns as correct
//   floating-point encodings of phi, gamma, C, or G.
//
// Semantics: R[rd] <- SacredROM[imm7]
//   imm7 in [0..74]   -> valid read,  valid_o=1, oob_o=0
//   imm7 in [75..127] -> out-of-bounds, oob_o=1, data_o=0 (UB per ISA spec)

`default_nettype none

module holo_load_phys_const #(
    parameter int unsigned ROM_DEPTH = 75,   // 75-cell Sacred ROM
    parameter int unsigned DATA_W    = 64    // 64-bit constants
) (
    input  wire                  clk,
    input  wire                  rst_n,

    // Instruction-issue interface (1-cycle ROM read)
    input  wire                  valid_i,    // instruction is valid this cycle
    input  wire [6:0]            imm7_i,     // Sacred ROM index (0..127)

    // Result interface (registered, available next cycle)
    output logic                 valid_o,    // output is valid
    output logic [DATA_W-1:0]    data_o,     // loaded constant
    output logic                 oob_o       // 1 = out-of-bounds (imm7 >= 75)
);

    // -------------------------------------------------------------------------
    // Sacred ROM declaration
    // -------------------------------------------------------------------------
    logic [DATA_W-1:0] sacred_rom [0:ROM_DEPTH-1];

    // -------------------------------------------------------------------------
    // Sacred ROM initialisation -- PLACEHOLDERS
    // Cells 0-3: symbolic sentinel values (non-zero for debug visibility).
    //   REPLACE with frozen-hash-validated constants after Lane E' P3.
    // Cells 4-74: zero (placeholder).
    // -------------------------------------------------------------------------
    initial begin : sacred_rom_init
        // Cell 0: phi (golden ratio ~1.6180339887...)
        // PLACEHOLDER -- to be replaced by Lane E' P3 frozen-hash-validated constant
        sacred_rom[0] = 64'hDEAD_0000_C0DE_0001; // phi sentinel

        // Cell 1: gamma = phi^-3 (~0.2360679774...)
        // PLACEHOLDER -- to be replaced by Lane E' P3 frozen-hash-validated constant
        sacred_rom[1] = 64'hDEAD_0000_C0DE_0002; // gamma = phi^-3 sentinel

        // Cell 2: C = phi^-1 (~0.6180339887...)
        // PLACEHOLDER -- to be replaced by Lane E' P3 frozen-hash-validated constant
        sacred_rom[2] = 64'hDEAD_0000_C0DE_0003; // C = phi^-1 sentinel

        // Cell 3: G = pi^3 * gamma^2 / phi
        // PLACEHOLDER -- to be replaced by Lane E' P3 frozen-hash-validated constant
        sacred_rom[3] = 64'hDEAD_0000_C0DE_0004; // G = pi^3*gamma^2/phi sentinel

        // Cells 4-74: zero placeholder
        for (int i = 4; i < ROM_DEPTH; i++) begin
            sacred_rom[i] = 64'h0000000000000000;
        end
    end

    // -------------------------------------------------------------------------
    // Out-of-bounds detection (combinatorial)
    // -------------------------------------------------------------------------
    wire oob_comb = (imm7_i >= 7'd75);

    // -------------------------------------------------------------------------
    // 1-cycle registered ROM read
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin : rom_read_ff
        if (!rst_n) begin
            valid_o <= 1'b0;
            data_o  <= {DATA_W{1'b0}};
            oob_o   <= 1'b0;
        end else begin
            valid_o <= valid_i;
            oob_o   <= valid_i & oob_comb;
            if (valid_i && !oob_comb) begin
                data_o <= sacred_rom[imm7_i];
            end else begin
                data_o <= {DATA_W{1'b0}};   // drive zero on OOB (UB region)
            end
        end
    end

endmodule

`default_nettype wire
