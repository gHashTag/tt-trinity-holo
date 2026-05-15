// =============================================================================
// holo_bitrom_bank.sv — BitROM bidirectional weight bank
// Lane W · L-DPC25 Wave-28 · OP_BITROM_READ = 0xE0
// =============================================================================
//
// Energy claim: 20.8 TOPS/W @ 65nm (arXiv 2509.08542,
//   "20.8 TOPS/W @ 65nm, 4 967 kB/mm² BitROM")
//   https://arxiv.org/abs/2509.08542
//
// Spec witness: bitrom_no_star lemma — coq/IGLA/RMarker.v
//   (t27 PR #637, commit 5758b53c)
//
// Hard Rules:
//   R-SI-1  : ZERO '*' operator anywhere in this file
//   R8      : Vasilev Dmitrii <admin@t27.ai>
//   R15     : 0xE0 continues sacred range after 0xDF (Lane V), 0xDE (Lane C')
//   R18     : Additive only — no existing holo_*.sv touched
//
// Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
//
// Parameters:
//   ROM_DEPTH  — number of entries (default 256)
//   WORD_WIDTH — width of each entry in bits (default 8)
//   ADDR_WIDTH — $clog2(ROM_DEPTH), derived
//
// Ports:
//   clk        — clock
//   rst_n      — active-low synchronous reset
//   valid_in   — opcode/address strobe
//   opcode     — 8-bit opcode; module gates on 8'hE0 (OP_BITROM_READ)
//   addr       — ADDR_WIDTH-bit read address
//   direction  — 1'b0 = forward  (rom[addr])
//                1'b1 = reverse  (rom[DEPTH-1-addr])
//   valid_out  — output valid (1-cycle latency)
//   weight_out — WORD_WIDTH-bit ROM data
//
// ROM init: rom[i] = i ^ 8'h5A  (XOR only — zero multiply)
// Latency:  1 clock cycle
// =============================================================================

`default_nettype none

module holo_bitrom_bank #(
    parameter integer ROM_DEPTH  = 256,
    parameter integer WORD_WIDTH = 8,
    parameter integer ADDR_WIDTH = $clog2(ROM_DEPTH)
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  valid_in,
    input  wire [7:0]            opcode,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire                  direction,
    output reg                   valid_out,
    output reg  [WORD_WIDTH-1:0] weight_out
);

    // -----------------------------------------------------------------------
    // OP_BITROM_READ opcode constant — 0xE0
    // R15: continues sacred range: 0xDE (Lane C') < 0xDF (Lane V) < 0xE0 (Lane W)
    // -----------------------------------------------------------------------
    localparam [7:0] OP_BITROM_READ = 8'hE0;

    // -----------------------------------------------------------------------
    // ROM storage — pre-loaded via synthesisable initial block
    // Pattern: rom[i] = i ^ 8'h5A   (XOR — R-SI-1 compliant, zero '*')
    // -----------------------------------------------------------------------
    reg [WORD_WIDTH-1:0] rom [0:ROM_DEPTH-1];

    integer init_i;
    initial begin : rom_init
        for (init_i = 0; init_i < ROM_DEPTH; init_i = init_i + 1) begin
            rom[init_i] = init_i[WORD_WIDTH-1:0] ^ 8'h5A;
        end
    end

    // -----------------------------------------------------------------------
    // Reverse-address computation — no multiply, pure subtraction
    // rev_addr = (ROM_DEPTH - 1) - addr
    // -----------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] rev_addr;
    assign rev_addr = {ADDR_WIDTH{1'b1}} - addr; // (2^ADDR_WIDTH - 1) - addr
                                                  // = (ROM_DEPTH-1) - addr when
                                                  //   ROM_DEPTH is power-of-2

    // -----------------------------------------------------------------------
    // Registered read — 1-cycle latency
    // -----------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] read_addr;
    assign read_addr = direction ? rev_addr : addr;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out  <= 1'b0;
            weight_out <= {WORD_WIDTH{1'b0}};
        end else begin
            if (valid_in && (opcode == OP_BITROM_READ)) begin
                valid_out  <= 1'b1;
                weight_out <= rom[read_addr];
            end else begin
                valid_out  <= 1'b0;
                weight_out <= {WORD_WIDTH{1'b0}};
            end
        end
    end

endmodule

`default_nettype wire
