// holo_bitrom_bank.sv — L-DPC25 Lane W · lever2-bitrom-bank
// Bidirectional ROM: 2 ternary weights per transistor
// Reference: arXiv 2509.08542 (BitROM, Yoshioka lab, ASP-DAC 2026)
// R-SI-1: NO * operators in synthesisable RTL
// Physical bidirectional ROM cell design DEFERRED to IHP SG13G2 floorplan / OpenLane2
// Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
// Author: admin@t27.ai

`default_nettype none

module holo_bitrom_bank #(
    // Number of ROM cells; each cell stores 2 ternary weights (WEIGHT_W bits each)
    parameter int unsigned CELL_COUNT = 64,
    // Bits per ternary weight (2 bits encodes {−1, 0, +1} in BitNet b1.58)
    parameter int unsigned WEIGHT_W   = 2,
    // Address width: one bit to select between the two weights in a cell,
    // remaining bits index the cell.  Total logical weight count = CELL_COUNT*2.
    // addr_i[0] is overridden by dir_i; addr_i[ADDR_W-1:1] selects the cell.
    parameter int unsigned ADDR_W     = 7  // log2(CELL_COUNT*2) = log2(128) = 7
) (
    input  wire                  clk_i,
    input  wire                  rst_ni,   // active-low synchronous reset

    // Read port
    input  wire                  valid_i,
    input  wire [ADDR_W-1:0]     addr_i,   // [ADDR_W-1:1] = cell index, [0] ignored (dir_i used)
    input  wire                  dir_i,    // 0 = UP → weight A (lower bits), 1 = DOWN → weight B (upper bits)

    // Read response (1-cycle pipeline)
    output logic                 valid_o,
    output logic [WEIGHT_W-1:0]  data_o,

    // Out-of-bounds flag
    output logic                 oob_o
);

    // -----------------------------------------------------------------
    // ROM array: each cell holds two packed ternary weights
    //   bits [WEIGHT_W-1:0]       → weight A (UP-direction read)
    //   bits [WEIGHT_W*2-1:WEIGHT_W] → weight B (DOWN-direction read)
    // -----------------------------------------------------------------
    localparam int unsigned CELL_BITS = WEIGHT_W * 2;  // 4 bits per cell

    logic [CELL_BITS-1:0] bitrom_cells [0:CELL_COUNT-1];

    // Sentinel pattern: 4'b1010
    //   weight A = 2'b10, weight B = 2'b10
    //   Real BitNet b1.58 weights loaded at chip-boot via separate initialisation flow
    initial begin : gen_sentinel
        for (int i = 0; i < CELL_COUNT; i++) begin
            bitrom_cells[i] = 4'b1010;
        end
    end

    // -----------------------------------------------------------------
    // Pipeline stage 1: decode cell index and direction, latch output
    // -----------------------------------------------------------------
    localparam int unsigned CELL_IDX_W = ADDR_W - 1;  // 6 bits for CELL_COUNT=64

    logic [CELL_IDX_W-1:0] cell_idx;
    logic                   addr_oob;

    // Cell index is upper bits of addr_i (bit 0 is don't-care; direction via dir_i)
    assign cell_idx  = addr_i[ADDR_W-1:1];
    // OOB when cell_idx >= CELL_COUNT
    assign addr_oob  = (cell_idx >= CELL_IDX_W'(CELL_COUNT));

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_o <= 1'b0;
            data_o  <= {WEIGHT_W{1'b0}};
            oob_o   <= 1'b0;
        end else begin
            valid_o <= valid_i;
            oob_o   <= valid_i & addr_oob;

            if (valid_i && !addr_oob) begin
                // dir_i == 0 → weight A = lower WEIGHT_W bits
                // dir_i == 1 → weight B = upper WEIGHT_W bits
                if (dir_i == 1'b0) begin
                    data_o <= bitrom_cells[cell_idx][WEIGHT_W-1:0];
                end else begin
                    data_o <= bitrom_cells[cell_idx][CELL_BITS-1:WEIGHT_W];
                end
            end else begin
                data_o <= {WEIGHT_W{1'b0}};
            end
        end
    end

endmodule

`default_nettype wire
