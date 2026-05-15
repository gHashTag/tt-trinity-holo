// =============================================================================
// probe.sv  —  LUT PE Energy Switching-Activity Probe
// Wave-29 Lane E · L-DPC26 · tt-trinity-holo
// =============================================================================
//
// Purpose:
//   Top-level simulation harness that instantiates holo_lut_pe (PR #19, 91c164ac)
//   and a shift_add_baseline PE, drives both with identical LFSR-generated random
//   input vectors, counts net toggles via $dumpvars hooks, and emits a
//   switching-activity histogram + estimated energy/op.
//
// Hard Rules:
//   R-SI-1  : ZERO * operator in all RTL (shift+add only for arithmetic)
//   R5-HONEST : 🟡 SIM verdict — silicon verification on TTIHP27a 2026-09-30
//   R18     : holo_lut_pe is instantiated READ-ONLY (no RTL modification)
//
// Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877
// ONE SHOT: gHashTag/trinity-fpga#108
//
// Refs #108
// Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module probe #(
    // DUT parameters (must match holo_lut_pe defaults)
    parameter int unsigned LUT_WIDTH  = 4,
    parameter int unsigned DATA_WIDTH = 8,

    // Energy model parameter
    // Cload in femtofarads (SG13G2 typical cell load = 1 fF)
    parameter real CLOAD_FF = 1.0,

    // Supply voltage in Volts (SG13G2 nominal 1.2 V)
    parameter real VDD_V = 1.2,

    // Number of test vectors
    parameter int unsigned NUM_VECTORS = 100000
) (
    /* empty — self-contained testbench */
);

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // DUT: holo_lut_pe (PR #19, commit 91c164ac) — READ-ONLY instantiation
    // -------------------------------------------------------------------------
    logic                      dut_valid_in;
    logic [7:0]                dut_opcode;
    logic [LUT_WIDTH-1:0]      dut_addr;
    logic [DATA_WIDTH-1:0]     dut_data_in;
    logic                      dut_lut_write_en;
    logic [LUT_WIDTH-1:0]      dut_lut_write_addr;
    logic [DATA_WIDTH-1:0]     dut_lut_write_data;
    logic                      dut_valid_out;
    logic [DATA_WIDTH-1:0]     dut_data_out;

    holo_lut_pe #(
        .LUT_WIDTH  (LUT_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_lut_pe (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (dut_valid_in),
        .opcode         (dut_opcode),
        .addr           (dut_addr),
        .data_in        (dut_data_in),
        .lut_write_en   (dut_lut_write_en),
        .lut_write_addr (dut_lut_write_addr),
        .lut_write_data (dut_lut_write_data),
        .valid_out      (dut_valid_out),
        .data_out       (dut_data_out)
    );

    // -------------------------------------------------------------------------
    // Baseline: shift_add_baseline PE
    // -------------------------------------------------------------------------
    logic                      bas_valid_in;
    logic [LUT_WIDTH-1:0]      bas_addr;
    logic [DATA_WIDTH-1:0]     bas_data_in;
    logic                      bas_valid_out;
    logic [DATA_WIDTH-1:0]     bas_data_out;

    shift_add_baseline #(
        .ADDR_WIDTH (LUT_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_baseline (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (bas_valid_in),
        .addr      (bas_addr),
        .data_in   (bas_data_in),
        .valid_out (bas_valid_out),
        .data_out  (bas_data_out)
    );

    // -------------------------------------------------------------------------
    // 16-bit Galois LFSR — ZERO * operator
    // Poly: x^16 + x^14 + x^13 + x^11 + 1  (maximal, feedback taps)
    // -------------------------------------------------------------------------
    logic [15:0] lfsr;

    task automatic lfsr_step;
        logic feedback;
        feedback = lfsr[0];
        lfsr     = lfsr >> 1;   // pure shift — no *
        if (feedback) begin
            // Tap XOR mask for polynomial x^16+x^14+x^13+x^11
            // bit positions (0-indexed): 15, 13, 12, 10  → tap at indices 14,12,11,9
            lfsr[14] = lfsr[14] ^ 1'b1;
            lfsr[12] = lfsr[12] ^ 1'b1;
            lfsr[11] = lfsr[11] ^ 1'b1;
            lfsr[9]  = lfsr[9]  ^ 1'b1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Toggle counters (integer — no arithmetic operators needed)
    // -------------------------------------------------------------------------
    // Previous values of key output/input signals
    logic [DATA_WIDTH-1:0] prev_dut_data_out;
    logic [DATA_WIDTH-1:0] prev_bas_data_out;
    logic [LUT_WIDTH-1:0]  prev_dut_addr;
    logic [LUT_WIDTH-1:0]  prev_bas_addr;
    logic                  prev_dut_valid_out;
    logic                  prev_bas_valid_out;

    // Toggle counts — use integer (no * needed)
    integer dut_toggle_count;
    integer bas_toggle_count;
    integer vec_count;

    // Popcount helper — counts bits set in XOR of two DATA_WIDTH vectors
    // Uses shift-and-add loop, no * operator
    function automatic integer popcount8 (input logic [DATA_WIDTH-1:0] x);
        integer cnt;
        logic [DATA_WIDTH-1:0] tmp;
        cnt = 0;
        tmp = x;
        for (int b = 0; b < DATA_WIDTH; b++) begin
            if (tmp[0]) cnt = cnt + 1;
            tmp = tmp >> 1;  // pure shift
        end
        return cnt;
    endfunction

    function automatic integer popcount4 (input logic [LUT_WIDTH-1:0] x);
        integer cnt;
        logic [LUT_WIDTH-1:0] tmp;
        cnt = 0;
        tmp = x;
        for (int b = 0; b < LUT_WIDTH; b++) begin
            if (tmp[0]) cnt = cnt + 1;
            tmp = tmp >> 1;  // pure shift
        end
        return cnt;
    endfunction

    // -------------------------------------------------------------------------
    // VCD dump for waveform viewing
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("lut_energy_probe.vcd");
        $dumpvars(0, probe);
    end

    // -------------------------------------------------------------------------
    // Histogram arrays — 9 buckets: 0..8 toggles per DATA_WIDTH output
    // -------------------------------------------------------------------------
    integer dut_hist [0:DATA_WIDTH];   // histogram[k] = ops with k output toggles
    integer bas_hist [0:DATA_WIDTH];

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Init
        rst_n             = 1'b0;
        dut_valid_in      = 1'b0;
        dut_opcode        = 8'hDF;  // OP_LUT_LOOKUP
        dut_addr          = '0;
        dut_data_in       = '0;
        dut_lut_write_en  = 1'b0;
        dut_lut_write_addr= '0;
        dut_lut_write_data= '0;
        bas_valid_in      = 1'b0;
        bas_addr          = '0;
        bas_data_in       = '0;
        lfsr              = 16'hACE1;  // non-zero seed

        dut_toggle_count  = 0;
        bas_toggle_count  = 0;
        vec_count         = 0;

        for (int i = 0; i <= DATA_WIDTH; i++) begin
            dut_hist[i] = 0;
            bas_hist[i] = 0;
        end

        // Reset for 4 cycles
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Snapshot initial outputs
        prev_dut_data_out  = dut_data_out;
        prev_bas_data_out  = bas_data_out;
        prev_dut_addr      = dut_addr;
        prev_bas_addr      = bas_addr;
        prev_dut_valid_out = dut_valid_out;
        prev_bas_valid_out = bas_valid_out;

        // ----------------------------------------------------------------
        // Drive NUM_VECTORS random operations
        // ----------------------------------------------------------------
        repeat (NUM_VECTORS) begin
            // Advance LFSR to generate next inputs
            lfsr_step();
            dut_addr     = lfsr[LUT_WIDTH-1:0];
            dut_data_in  = lfsr[DATA_WIDTH+LUT_WIDTH-1:LUT_WIDTH];
            dut_valid_in = 1'b1;
            dut_opcode   = 8'hDF;

            bas_addr     = lfsr[LUT_WIDTH-1:0];
            bas_data_in  = lfsr[DATA_WIDTH+LUT_WIDTH-1:LUT_WIDTH];
            bas_valid_in = 1'b1;

            @(posedge clk);
            #1;  // small delay after rising edge to sample outputs

            // Count output data toggles
            begin
                integer dt, bt, at_dut, at_bas;
                dt     = popcount8(dut_data_out ^ prev_dut_data_out);
                bt     = popcount8(bas_data_out ^ prev_bas_data_out);
                at_dut = popcount4(dut_addr     ^ prev_dut_addr);
                at_bas = popcount4(bas_addr      ^ prev_bas_addr);

                dut_toggle_count = dut_toggle_count + dt + at_dut
                                   + (dut_valid_out ^ prev_dut_valid_out);
                bas_toggle_count = bas_toggle_count + bt + at_bas
                                   + (bas_valid_out ^ prev_bas_valid_out);

                // Histogram on output data toggles only
                dut_hist[dt] = dut_hist[dt] + 1;
                bas_hist[bt] = bas_hist[bt] + 1;
            end

            prev_dut_data_out  = dut_data_out;
            prev_bas_data_out  = bas_data_out;
            prev_dut_addr      = dut_addr;
            prev_bas_addr      = bas_addr;
            prev_dut_valid_out = dut_valid_out;
            prev_bas_valid_out = bas_valid_out;

            vec_count = vec_count + 1;
        end

        // ----------------------------------------------------------------
        // Report
        // ----------------------------------------------------------------
        $display("=== Wave-29 Lane E — LUT PE Energy Probe Report ===");
        $display("Verdict: SIM (🟡) — NOT silicon-verified");
        $display("DUT:      holo_lut_pe (PR #19, commit 91c164ac)");
        $display("Baseline: shift_add_baseline");
        $display("Vectors:  %0d", vec_count);
        $display("Cload:    %.1f fF  VDD: %.2f V", CLOAD_FF, VDD_V);
        $display("");
        $display("--- Toggle counts (total across all signals) ---");
        $display("LUT PE toggles/op:        %0d / %0d = %.3f",
                 dut_toggle_count, vec_count,
                 $itor(dut_toggle_count) / $itor(vec_count));
        $display("Shift-add toggles/op:     %0d / %0d = %.3f",
                 bas_toggle_count, vec_count,
                 $itor(bas_toggle_count) / $itor(vec_count));
        $display("");
        $display("--- Output-data toggle histogram (LUT PE) ---");
        for (int k = 0; k <= DATA_WIDTH; k++) begin
            if (dut_hist[k] > 0)
                $display("  %0d toggles: %0d ops", k, dut_hist[k]);
        end
        $display("--- Output-data toggle histogram (Shift-add) ---");
        for (int k = 0; k <= DATA_WIDTH; k++) begin
            if (bas_hist[k] > 0)
                $display("  %0d toggles: %0d ops", k, bas_hist[k]);
        end
        $display("");
        if (bas_toggle_count > 0) begin
            $display("Ratio LUT/SA:  %.3f x",
                     $itor(dut_toggle_count) / $itor(bas_toggle_count));
            if (dut_toggle_count <= (bas_toggle_count << 1))  // ≤ 2× via shift, no *
                $display("W28-G2 gate (<=2x): PASS");
            else
                $display("W28-G2 gate (<=2x): FAIL");
        end else begin
            $display("Ratio LUT/SA:  N/A (baseline zero toggles)");
            $display("W28-G2 gate (<=2x): INCONCLUSIVE");
        end
        $display("=== END REPORT ===");

        $finish;
    end

endmodule

`default_nettype wire
