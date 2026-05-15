// =============================================================================
// holo_razor_ff_tb.sv — Testbench for holo_razor_ff
// TTSKY26c HOLOGRAPHIC SKU · L-DPC24 Lane B'
// =============================================================================
// Test plan:
//   1. Stable value test  — d held constant across all edges → error_out == 0
//   2. Glitch injection   — d changed between rising and falling edge → error_out == 1
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module holo_razor_ff_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int W      = 32;
    localparam int CLK_PERIOD = 10; // ns (100 MHz)

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic          clk;
    logic          rst_n;
    logic [W-1:0]  d;
    logic [W-1:0]  q;
    logic [W-1:0]  q_shadow;
    logic          error_out;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    holo_razor_ff #(.W(W)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .d        (d),
        .q        (q),
        .q_shadow (q_shadow),
        .error_out(error_out)
    );

    // -------------------------------------------------------------------------
    // Clock generation: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    integer fail_count;

    initial begin
        fail_count = 0;
        rst_n      = 1'b0;
        d          = {W{1'b0}};

        // ---- Release reset after two rising edges -------------------------
        repeat(2) @(posedge clk);
        #1;
        rst_n = 1'b1;

        // =========================================================
        // TEST 1 — Stable value: d held across all edges → error_out == 0
        // =========================================================
        d = 32'hDEAD_BEEF;
        repeat(4) @(posedge clk);
        #1; // small delta after rising edge; d still stable

        // Let one full cycle pass, then sample after falling edge
        @(negedge clk);
        #1;

        if (error_out !== 1'b0) begin
            $display("FAIL: TEST1 — expected error_out=0, got error_out=%b at t=%0t",
                     error_out, $time);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: TEST1 — stable value, error_out=0 at t=%0t", $time);
        end

        // =========================================================
        // TEST 2 — Glitch injection: change d AFTER rising edge
        //          but BEFORE falling edge → error_out == 1
        // =========================================================
        //
        // At posedge clk   : main flop captures OLD value (32'hDEAD_BEEF)
        // Shortly after     : drive d to a new value (32'hCAFE_BABE)
        // At negedge clk   : shadow flop captures NEW value
        // => q != q_shadow => error_out == 1
        //
        @(posedge clk);
        #2; // 2 ns after rising edge (well within half-period of 5 ns)
        d = 32'hCAFE_BABE;

        // Wait for the falling edge to latch the new value into q_shadow
        @(negedge clk);
        #1;

        if (error_out !== 1'b1) begin
            $display("FAIL: TEST2 — expected error_out=1, got error_out=%b at t=%0t",
                     error_out, $time);
            fail_count = fail_count + 1;
        end else begin
            $display("R5-HONEST: razor error_out captured at t=%0t", $time);
        end

        // =========================================================
        // TEST 3 — After glitch: stabilise d, error_out clears
        // =========================================================
        // Let the new stable value propagate through both flops
        repeat(2) @(posedge clk);
        #1;
        @(negedge clk);
        #1;

        if (error_out !== 1'b0) begin
            $display("FAIL: TEST3 — expected error_out=0 after stabilisation, got %b at t=%0t",
                     error_out, $time);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: TEST3 — error_out cleared after stabilisation at t=%0t", $time);
        end

        // =========================================================
        // Summary
        // =========================================================
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d failure(s)", fail_count);

        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("TIMEOUT — simulation exceeded 10 us");
        $finish;
    end

endmodule

`default_nettype wire

// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
