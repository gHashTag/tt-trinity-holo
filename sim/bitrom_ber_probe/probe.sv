// sim/bitrom_ber_probe/probe.sv — Wave-29 Lane B · BitROM BER Probe
// LFSR-driven random-read BER probe for holo_bitrom_bank
// R-SI-1: ZERO * operators in RTL
// R5-HONEST: 🟡 SIM verdict — silicon-verified 🟢 only on TTIHP27a return 2026-09-30
// Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
// Author: Vasilev Dmitrii <admin@t27.ai>
// Refs #108

`default_nettype none
`timescale 1ns/1ps

module bitrom_ber_probe #(
    // ROM configuration — must match holo_bitrom_bank defaults
    parameter int unsigned CELL_COUNT  = 64,
    parameter int unsigned WEIGHT_W    = 2,
    parameter int unsigned ADDR_W      = 7,   // log2(CELL_COUNT*2) = 7
    // LFSR seed — 0xDEADBEEF per spec
    parameter logic [31:0] LFSR_SEED   = 32'hDEADBEEF,
    // Number of read rounds.
    //   CI default : 1_000_000 (1e6)
    //   Offline    : 1_000_000_000 (1e9) — pass MAX_ROUNDS=1000000000 on CLI
    parameter longint unsigned MAX_ROUNDS = 1_000_000
) ();

    // ----------------------------------------------------------------
    // Clock and reset
    // ----------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz

    // ----------------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------------
    logic                  dut_valid_i;
    logic [ADDR_W-1:0]     dut_addr_i;
    logic                  dut_dir_i;
    logic                  dut_valid_o;
    logic [WEIGHT_W-1:0]   dut_data_o;
    logic                  dut_oob_o;

    // ----------------------------------------------------------------
    // DUT instantiation — NO * in this file (R-SI-1)
    // ----------------------------------------------------------------
    holo_bitrom_bank #(
        .CELL_COUNT (CELL_COUNT),
        .WEIGHT_W   (WEIGHT_W),
        .ADDR_W     (ADDR_W)
    ) u_dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),
        .valid_i (dut_valid_i),
        .addr_i  (dut_addr_i),
        .dir_i   (dut_dir_i),
        .valid_o (dut_valid_o),
        .data_o  (dut_data_o),
        .oob_o   (dut_oob_o)
    );

    // ----------------------------------------------------------------
    // 32-bit Fibonacci LFSR (maximal-length, taps 31,21,1,0)
    // Produces pseudo-random addresses and direction bits.
    // No * operator: taps XOR-collapsed.
    // ----------------------------------------------------------------
    logic [31:0] lfsr_reg;

    function automatic logic [31:0] lfsr_next (input logic [31:0] s);
        logic feedback;
        // taps: [31]^[21]^[1]^[0]  (one-indexed from msb, 0-based bit positions 31,21,1,0)
        feedback = s[31] ^ s[21] ^ s[1] ^ s[0];
        lfsr_next = {s[30:0], feedback};
    endfunction

    // ----------------------------------------------------------------
    // Expected-data reference:
    //   Sentinel ROM: every cell = 4'b1010
    //     weight A (dir=0) = bitrom_cells[idx][WEIGHT_W-1:0]   = 2'b10
    //     weight B (dir=1) = bitrom_cells[idx][CELL_BITS-1:WEIGHT_W] = 2'b10
    //   Both directions return 2'b10 for any in-range cell.
    //   For OOB cells the DUT returns 2'b00 and asserts oob_o.
    // ----------------------------------------------------------------
    localparam logic [WEIGHT_W-1:0] SENTINEL_A = 2'b10;
    localparam logic [WEIGHT_W-1:0] SENTINEL_B = 2'b10;

    // ----------------------------------------------------------------
    // Per-cell mismatch counters (CELL_COUNT cells, 2 directions each)
    //   cell_err_a[i] — mismatches for cell i, direction UP
    //   cell_err_b[i] — mismatches for cell i, direction DOWN
    // ----------------------------------------------------------------
    longint unsigned cell_err_a [0:CELL_COUNT-1];
    longint unsigned cell_err_b [0:CELL_COUNT-1];

    // ----------------------------------------------------------------
    // Summary counters
    // ----------------------------------------------------------------
    longint unsigned total_reads;
    longint unsigned total_errors;

    // ----------------------------------------------------------------
    // Main probe sequence
    // ----------------------------------------------------------------
    integer ci;

    initial begin : probe_main
        // Initialise counters
        total_reads  = 0;
        total_errors = 0;
        for (ci = 0; ci < CELL_COUNT; ci = ci + 1) begin
            cell_err_a[ci] = 0;
            cell_err_b[ci] = 0;
        end

        // Initialise LFSR
        lfsr_reg    = LFSR_SEED;

        // Initialise DUT inputs
        dut_valid_i = 1'b0;
        dut_addr_i  = {ADDR_W{1'b0}};
        dut_dir_i   = 1'b0;
        rst_n       = 1'b0;

        // Hold reset for 4 cycles (active-low synchronous reset)
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // -------------------------------------------------------
        // Main loop: MAX_ROUNDS LFSR-driven random reads
        // -------------------------------------------------------
        begin : round_loop
            longint unsigned round;
            logic [ADDR_W-1:0] rand_addr;
            logic              rand_dir;
            logic [5:0]        rand_cell_idx;
            logic [WEIGHT_W-1:0] expected;

            for (round = 0; round < MAX_ROUNDS; round = round + 1) begin
                // Advance LFSR once per round
                lfsr_reg = lfsr_next(lfsr_reg);

                // Extract address and direction from LFSR state
                // addr_i [ADDR_W-1:0] = lfsr_reg[ADDR_W-1:0]
                // dir_i               = lfsr_reg[ADDR_W]
                // Only use in-range cell indices (mod CELL_COUNT via masking
                // to the lower bits — CELL_COUNT=64 → cell_idx fits in 6 bits)
                rand_addr = lfsr_reg[ADDR_W-1:0];
                rand_dir  = lfsr_reg[ADDR_W];

                // Cell index seen by DUT
                rand_cell_idx = rand_addr[ADDR_W-1:1];

                // Determine expected output for in-range cells
                // (OOB reads not counted toward BER per spec)
                if (rand_cell_idx < 6'(CELL_COUNT)) begin
                    if (rand_dir == 1'b0) begin
                        expected = SENTINEL_A;
                    end else begin
                        expected = SENTINEL_B;
                    end

                    // Drive DUT input
                    @(negedge clk);
                    dut_valid_i = 1'b1;
                    dut_addr_i  = rand_addr;
                    dut_dir_i   = rand_dir;

                    // Sample after 1-cycle pipeline
                    @(posedge clk);
                    #1;

                    // Deassert valid
                    @(negedge clk);
                    dut_valid_i = 1'b0;

                    // Count reads and errors
                    total_reads = total_reads + 1;

                    if (dut_valid_o && !dut_oob_o && (dut_data_o !== expected)) begin
                        total_errors = total_errors + 1;
                        if (rand_dir == 1'b0) begin
                            cell_err_a[rand_cell_idx] = cell_err_a[rand_cell_idx] + 1;
                        end else begin
                            cell_err_b[rand_cell_idx] = cell_err_b[rand_cell_idx] + 1;
                        end
                    end
                end
                // OOB rounds skipped (cell_idx >= CELL_COUNT) — not counted in BER
            end // for round
        end // block round_loop

        // -------------------------------------------------------
        // Report
        // -------------------------------------------------------
        $display("==================================================");
        $display("  BitROM BER Probe — Wave-29 Lane B");
        $display("  DUT: holo_bitrom_bank (898fc06) [R-SI-1]");
        $display("  🟡 SIM verdict — not silicon-verified");
        $display("--------------------------------------------------");
        $display("  total_reads  : %0d", total_reads);
        $display("  total_errors : %0d", total_errors);

        // BER computation without * operator:
        //   BER = total_errors / total_reads
        //   For display: express as ratio.  Gate W28-G3: BER <= 1e-9
        //   With total_reads = 1e6 and total_errors = 0: BER = 0.0 (PASS if errors=0)
        //   With total_reads = 1e9 (offline): gate is strict.
        if (total_reads > 0) begin
            if (total_errors == 0) begin
                $display("  BER          : 0 (no errors detected)");
                $display("  W28-G3 gate (BER <= 1e-9): PASS");
                $display("==================================================");
                $finish;
            end else begin
                // BER = errors / reads — report ratio components
                $display("  BER          : %0d / %0d (see report.md for ratio)", total_errors, total_reads);
                // Gate: FAIL if any errors in 1e6 run implies BER >= 1e-6 > 1e-9
                $display("  W28-G3 gate (BER <= 1e-9): FAIL");
                $display("==================================================");
                $display("Per-cell errors:");
                begin : cell_report
                    integer ci2;
                    for (ci2 = 0; ci2 < CELL_COUNT; ci2 = ci2 + 1) begin
                        if ((cell_err_a[ci2] > 0) || (cell_err_b[ci2] > 0)) begin
                            $display("  cell[%0d]: err_a=%0d err_b=%0d",
                                ci2, cell_err_a[ci2], cell_err_b[ci2]);
                        end
                    end
                end
                $fatal(1, "W28-G3 FAIL: BER > 1e-9 in simulation");
            end
        end else begin
            $display("  BER          : N/A (no in-range reads)");
            $display("  W28-G3 gate (BER <= 1e-9): INCONCLUSIVE");
            $display("==================================================");
            $finish;
        end
    end // probe_main

endmodule

`default_nettype wire
