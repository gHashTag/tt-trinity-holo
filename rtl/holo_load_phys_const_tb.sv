// holo_load_phys_const_tb.sv
// Testbench for holo_load_phys_const — L-DPC24 Lane C'
//
// Issue:  https://github.com/gHashTag/trinity-fpga/issues/99
// Author: admin@t27.ai
// Anchor: φ²+φ⁻²=3
//
// Test 1: imm7=0  → data_o = φ placeholder, valid_o=1, oob_o=0
// Test 2: imm7=74 → valid_o=1, oob_o=0  (last valid cell)
// Test 3: imm7=75 → oob_o=1             (first UB cell)

`default_nettype none
`timescale 1ns/1ps

module holo_load_phys_const_tb;

    // ─── DUT signals ────────────────────────────────────────────────────────
    logic        clk;
    logic        rst_n;
    logic        valid_i;
    logic [6:0]  imm7_i;

    logic        valid_o;
    logic [63:0] data_o;
    logic        oob_o;

    // ─── DUT instantiation ──────────────────────────────────────────────────
    holo_load_phys_const #(
        .ROM_DEPTH (75),
        .DATA_W    (64)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_i (valid_i),
        .imm7_i  (imm7_i),
        .valid_o (valid_o),
        .data_o  (data_o),
        .oob_o   (oob_o)
    );

    // ─── Clock generation ───────────────────────────────────────────────────
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz

    // ─── Test helpers ────────────────────────────────────────────────────────
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string  test_name,
        input logic   got_valid,
        input logic   got_oob,
        input logic   exp_valid,
        input logic   exp_oob
    );
        if (got_valid === exp_valid && got_oob === exp_oob) begin
            $display("[PASS] %s : valid_o=%0b oob_o=%0b", test_name, got_valid, got_oob);
            pass_count++;
        end else begin
            $display("[FAIL] %s : got valid_o=%0b oob_o=%0b  expected valid_o=%0b oob_o=%0b",
                     test_name, got_valid, got_oob, exp_valid, exp_oob);
            fail_count++;
        end
    endtask

    // ─── Stimulus ────────────────────────────────────────────────────────────
    initial begin : tb_main
        // Reset
        rst_n   = 1'b0;
        valid_i = 1'b0;
        imm7_i  = 7'd0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ── Test 1: imm7=0 → φ placeholder, valid_o=1, oob_o=0 ─────────────
        valid_i = 1'b1;
        imm7_i  = 7'd0;
        @(posedge clk);   // issue cycle
        valid_i = 1'b0;
        @(posedge clk);   // result latches on this edge → sample after
        // Sample outputs (registered, available 1 cycle after issue)
        check("Test1_imm7=0_phi_placeholder",
              valid_o, oob_o,
              1'b1,    1'b0);
        // Also confirm data_o is the φ placeholder (non-zero sentinel)
        if (data_o !== 64'h0000000000000000) begin
            $display("[PASS] Test1_phi_data_nonzero : data_o=0x%016h (placeholder present)", data_o);
            pass_count++;
        end else begin
            $display("[FAIL] Test1_phi_data_nonzero : data_o=0 (placeholder missing?)");
            fail_count++;
        end

        // ── Test 2: imm7=74 → last valid cell, valid_o=1, oob_o=0 ──────────
        @(posedge clk);
        valid_i = 1'b1;
        imm7_i  = 7'd74;
        @(posedge clk);
        valid_i = 1'b0;
        @(posedge clk);
        check("Test2_imm7=74_last_valid",
              valid_o, oob_o,
              1'b1,    1'b0);

        // ── Test 3: imm7=75 → OOB, oob_o=1 ─────────────────────────────────
        @(posedge clk);
        valid_i = 1'b1;
        imm7_i  = 7'd75;
        @(posedge clk);
        valid_i = 1'b0;
        @(posedge clk);
        check("Test3_imm7=75_oob",
              valid_o, oob_o,
              1'b1,    1'b1);
        // data_o must be 0 in OOB case
        if (data_o === 64'h0000000000000000) begin
            $display("[PASS] Test3_oob_data_zero : data_o=0 on OOB as required");
            pass_count++;
        end else begin
            $display("[FAIL] Test3_oob_data_zero : data_o=0x%016h on OOB (expected 0)", data_o);
            fail_count++;
        end

        // ── Summary ─────────────────────────────────────────────────────────
        $display("─────────────────────────────────────────");
        $display("TB SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        $display("Anchor: φ²+φ⁻²=3");
        $display("NOTE: ROM constants are PLACEHOLDERS.");
        $display("      Replace after Lane E' P3 frozen-hash is established.");
        $display("─────────────────────────────────────────");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: FAILURES DETECTED — see above");

        $finish;
    end

endmodule

`default_nettype wire
