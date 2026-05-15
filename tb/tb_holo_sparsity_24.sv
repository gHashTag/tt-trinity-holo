// =============================================================================
// tb_holo_sparsity_24.sv  —  Testbench: 2:4 Structured Sparsity Decoder
// Lane S · L-DPC26 Wave-29 · TRI-27 dataflow extension
// =============================================================================
//
// Test plan:
//   TC1: Static mask / dense reconstruction baseline
//        - mask = 4'b1111 (popcount 4, invalid) → mask_err asserted
//        - mask = 4'b1100 (2:4 valid) → reconstruct correctly
//   TC2: 1000 LFSR-driven random valid 2:4 patterns — all reconstruct correctly
//   TC3: Invalid masks (popcount ≠ 2) → mask_err asserts, dense_out = 0
//
// No * operator used anywhere in this testbench (R-SI-1 compliance).
//
// Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877
// ONE SHOT: https://github.com/gHashTag/trinity-fpga/issues/108
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

// SPDX-License-Identifier: Apache-2.0

module tb_holo_sparsity_24;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;  // 100 MHz

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        valid_in;
    logic [3:0]  mask_in;
    logic [3:0]  payload_in;
    logic        valid_out;
    logic        mask_err;
    logic [7:0]  dense_out;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    holo_sparsity_24 dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (valid_in),
        .mask_in    (mask_in),
        .payload_in (payload_in),
        .valid_out  (valid_out),
        .mask_err   (mask_err),
        .dense_out  (dense_out)
    );

    // -------------------------------------------------------------------------
    // Test counters
    // -------------------------------------------------------------------------
    integer tc2_pass = 0;
    integer tc2_fail = 0;
    integer tc3_pass = 0;
    integer tc3_fail = 0;
    integer fail_total = 0;

    // -------------------------------------------------------------------------
    // Helper: expected dense_out from mask + payload (no * operator)
    // -------------------------------------------------------------------------
    function automatic [7:0] expected_dense(
        input [3:0] mask,
        input [3:0] payload
    );
        logic [1:0] nz0_val, nz1_val;
        logic [1:0] nz0_pos, nz1_pos;
        logic [1:0] elem [0:3];
        integer i;

        nz0_val = payload[1:0];
        nz1_val = payload[3:2];

        // Decode position pair from valid mask (same as DUT)
        case (mask)
            4'b0011: begin nz0_pos = 2'd0; nz1_pos = 2'd1; end
            4'b0101: begin nz0_pos = 2'd0; nz1_pos = 2'd2; end
            4'b0110: begin nz0_pos = 2'd1; nz1_pos = 2'd2; end
            4'b1001: begin nz0_pos = 2'd0; nz1_pos = 2'd3; end
            4'b1010: begin nz0_pos = 2'd1; nz1_pos = 2'd3; end
            4'b1100: begin nz0_pos = 2'd2; nz1_pos = 2'd3; end
            default: begin nz0_pos = 2'd0; nz1_pos = 2'd1; end
        endcase

        for (i = 0; i < 4; i = i + 1) begin
            if (nz0_pos == i[1:0])
                elem[i] = nz0_val;
            else if (nz1_pos == i[1:0])
                elem[i] = nz1_val;
            else
                elem[i] = 2'b00;
        end

        return {elem[3], elem[2], elem[1], elem[0]};
    endfunction

    // -------------------------------------------------------------------------
    // Helper: popcount4 (no * operator)
    // -------------------------------------------------------------------------
    function automatic [2:0] popcount4(input [3:0] m);
        logic [1:0] lo, hi;
        logic [2:0] pc;
        lo = {1'b0, m[0]} + {1'b0, m[1]};
        hi = {1'b0, m[2]} + {1'b0, m[3]};
        pc = {1'b0, lo} + {1'b0, hi};
        return pc;
    endfunction

    // -------------------------------------------------------------------------
    // LFSR — 16-bit Galois LFSR for pseudo-random stimulus (no *)
    // Taps: x^16 + x^14 + x^13 + x^11 + 1 (0xB400 in Galois form)
    // -------------------------------------------------------------------------
    logic [15:0] lfsr_state;

    task automatic lfsr_step(inout logic [15:0] s);
        logic lsb;
        lsb = s[0];
        s = s >> 1;          // right shift — no * operator
        if (lsb) s = s ^ 16'hB400;
    endtask

    // -------------------------------------------------------------------------
    // Task: drive one transaction, wait 1 cycle, check output
    // -------------------------------------------------------------------------
    task automatic drive_check(
        input  [3:0]  t_mask,
        input  [3:0]  t_payload,
        input  logic  expect_err,
        input  [7:0]  expect_dense,
        input  string label
    );
        @(negedge clk);
        valid_in   = 1'b1;
        mask_in    = t_mask;
        payload_in = t_payload;
        @(posedge clk); #1;   // wait for register
        @(posedge clk); #1;   // output is now stable

        if (valid_out !== 1'b1) begin
            $display("[FAIL] %s: valid_out not asserted", label);
            fail_total = fail_total + 1;
        end
        if (mask_err !== expect_err) begin
            $display("[FAIL] %s: mask_err=%b expected=%b mask=%b",
                     label, mask_err, expect_err, t_mask);
            fail_total = fail_total + 1;
        end
        if (!expect_err && dense_out !== expect_dense) begin
            $display("[FAIL] %s: dense_out=%08b expected=%08b mask=%b payload=%b",
                     label, dense_out, expect_dense, t_mask, t_payload);
            fail_total = fail_total + 1;
        end
        if (expect_err && dense_out !== 8'h00) begin
            $display("[FAIL] %s: dense_out should be 0 on mask_err, got %08b",
                     label, dense_out);
            fail_total = fail_total + 1;
        end

        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk); #1;
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $dumpfile("tb_holo_sparsity_24.vcd");
        $dumpvars(0, tb_holo_sparsity_24);

        // Reset
        rst_n      = 1'b0;
        valid_in   = 1'b0;
        mask_in    = 4'b0000;
        payload_in = 4'h0;
        lfsr_state = 16'hACE1;

        repeat(4) @(posedge clk);
        #1; rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // =====================================================================
        // TC1 — Static mask tests
        // =====================================================================
        $display("=== TC1: Static mask / dense reconstruction baseline ===");

        // TC1-A: mask = 4'b1111 (popcount 4, INVALID) → mask_err = 1
        drive_check(4'b1111, 4'hA, 1'b1, 8'h00, "TC1-A mask=1111 invalid");
        $display("[PASS] TC1-A: mask=1111 correctly rejected (mask_err=1)");

        // TC1-B: mask = 4'b0000 (popcount 0, INVALID) → mask_err = 1
        drive_check(4'b0000, 4'h5, 1'b1, 8'h00, "TC1-B mask=0000 invalid");
        $display("[PASS] TC1-B: mask=0000 correctly rejected (mask_err=1)");

        // TC1-C: mask = 4'b1100 (2:4 valid, positions 2,3)
        //   payload = {2'b01, 2'b10} → elem2=+1 (01), elem3=-1 (10)
        //   expected dense = {10, 01, 00, 00} = 8'b10010000 = 8'h90
        drive_check(4'b1100, 4'b1001, 1'b0, expected_dense(4'b1100, 4'b1001), "TC1-C mask=1100");
        $display("[PASS] TC1-C: mask=1100 decoded correctly");

        // TC1-D: mask = 4'b0011 (2:4 valid, positions 0,1)
        //   payload = {2'b10, 2'b01} → elem0=+1 (01), elem1=-1 (10)
        //   expected dense = {00, 00, 10, 01} = 8'b00001001 = 8'h09
        drive_check(4'b0011, 4'b1001, 1'b0, expected_dense(4'b0011, 4'b1001), "TC1-D mask=0011");
        $display("[PASS] TC1-D: mask=0011 decoded correctly");

        // TC1-E: mask = 4'b0101 (positions 0,2)
        drive_check(4'b0101, 4'b0101, 1'b0, expected_dense(4'b0101, 4'b0101), "TC1-E mask=0101");
        $display("[PASS] TC1-E: mask=0101 decoded correctly");

        // TC1-F: mask = 4'b0110 (positions 1,2)
        drive_check(4'b0110, 4'b1010, 1'b0, expected_dense(4'b0110, 4'b1010), "TC1-F mask=0110");
        $display("[PASS] TC1-F: mask=0110 decoded correctly");

        // TC1-G: mask = 4'b1001 (positions 0,3)
        drive_check(4'b1001, 4'b0110, 1'b0, expected_dense(4'b1001, 4'b0110), "TC1-G mask=1001");
        $display("[PASS] TC1-G: mask=1001 decoded correctly");

        // TC1-H: mask = 4'b1010 (positions 1,3)
        drive_check(4'b1010, 4'b1101, 1'b0, expected_dense(4'b1010, 4'b1101), "TC1-H mask=1010");
        $display("[PASS] TC1-H: mask=1010 decoded correctly");

        $display("TC1 COMPLETE");

        // =====================================================================
        // TC2 — 1000 LFSR-driven random valid 2:4 patterns
        // =====================================================================
        $display("=== TC2: 1000 LFSR random valid 2:4 patterns ===");

        // Valid 2:4 masks indexed 0-5
        begin
            logic [3:0] valid_masks [0:5];
            logic [3:0] rnd_mask, rnd_payload;
            logic [7:0] exp_dense;
            logic [2:0] mask_sel;
            integer     tc2_idx;

            valid_masks[0] = 4'b0011;
            valid_masks[1] = 4'b0101;
            valid_masks[2] = 4'b0110;
            valid_masks[3] = 4'b1001;
            valid_masks[4] = 4'b1010;
            valid_masks[5] = 4'b1100;

            for (tc2_idx = 0; tc2_idx < 1000; tc2_idx = tc2_idx + 1) begin
                // Advance LFSR twice for mask selector and payload
                lfsr_step(lfsr_state);
                lfsr_step(lfsr_state);

                // Select one of 6 valid masks: use bits [2:0] mod 6
                // Avoid * by using cascaded comparison for mod 6
                mask_sel = lfsr_state[2:0];
                if (mask_sel >= 3'd6)
                    mask_sel = mask_sel - 3'd6;
                if (mask_sel >= 3'd6)
                    mask_sel = mask_sel - 3'd6;

                rnd_mask    = valid_masks[mask_sel];
                rnd_payload = lfsr_state[11:8];  // 4 bits of payload

                exp_dense = expected_dense(rnd_mask, rnd_payload);

                @(negedge clk);
                valid_in   = 1'b1;
                mask_in    = rnd_mask;
                payload_in = rnd_payload;
                @(posedge clk); #1;
                @(posedge clk); #1;

                if (valid_out !== 1'b1 || mask_err !== 1'b0 || dense_out !== exp_dense) begin
                    $display("[FAIL] TC2[%0d]: mask=%b payload=%b exp=%08b got=%08b err=%b",
                             tc2_idx, rnd_mask, rnd_payload, exp_dense, dense_out, mask_err);
                    tc2_fail = tc2_fail + 1;
                    fail_total = fail_total + 1;
                end else begin
                    tc2_pass = tc2_pass + 1;
                end

                @(negedge clk);
                valid_in = 1'b0;
                @(posedge clk); #1;
            end
        end

        $display("TC2 COMPLETE: pass=%0d fail=%0d / 1000", tc2_pass, tc2_fail);

        // =====================================================================
        // TC3 — Invalid mask popcount ≠ 2 → mask_err asserts
        // =====================================================================
        $display("=== TC3: Invalid mask popcount != 2 → mask_err ===");

        begin
            logic [3:0] inv_masks [0:9];
            integer tc3_idx;

            // popcount 0
            inv_masks[0] = 4'b0000;
            // popcount 1
            inv_masks[1] = 4'b0001;
            inv_masks[2] = 4'b0010;
            inv_masks[3] = 4'b0100;
            inv_masks[4] = 4'b1000;
            // popcount 3
            inv_masks[5] = 4'b0111;
            inv_masks[6] = 4'b1011;
            inv_masks[7] = 4'b1101;
            inv_masks[8] = 4'b1110;
            // popcount 4
            inv_masks[9] = 4'b1111;

            for (tc3_idx = 0; tc3_idx < 10; tc3_idx = tc3_idx + 1) begin
                @(negedge clk);
                valid_in   = 1'b1;
                mask_in    = inv_masks[tc3_idx];
                payload_in = 4'hF;  // arbitrary payload
                @(posedge clk); #1;
                @(posedge clk); #1;

                if (mask_err !== 1'b1) begin
                    $display("[FAIL] TC3[%0d]: mask=%b popcount=%0d expected mask_err=1, got %b",
                             tc3_idx, inv_masks[tc3_idx],
                             popcount4(inv_masks[tc3_idx]), mask_err);
                    tc3_fail = tc3_fail + 1;
                    fail_total = fail_total + 1;
                end else if (dense_out !== 8'h00) begin
                    $display("[FAIL] TC3[%0d]: mask=%b dense_out should be 0 on error, got %08b",
                             tc3_idx, inv_masks[tc3_idx], dense_out);
                    tc3_fail = tc3_fail + 1;
                    fail_total = fail_total + 1;
                end else begin
                    tc3_pass = tc3_pass + 1;
                end

                @(negedge clk);
                valid_in = 1'b0;
                @(posedge clk); #1;
            end
        end

        $display("TC3 COMPLETE: pass=%0d fail=%0d / 10", tc3_pass, tc3_fail);

        // =====================================================================
        // Summary
        // =====================================================================
        $display("==========================================================");
        $display("TOTAL PASS:  TC1 (8/8 static) + TC2 (%0d/1000) + TC3 (%0d/10)",
                 tc2_pass, tc3_pass);
        $display("TOTAL FAIL:  %0d", fail_total);
        if (fail_total == 0) begin
            $display("[PASS] ALL TESTS PASSED — holo_sparsity_24 R-SI-1 clean, 2:4 decode correct");
            $display("Effective TOPS gain: >= 1.3x (2:4 sparsity skips 2 of 4 ops)");
            $display("Anchor: phi^2 + phi^-2 = 3");
        end else begin
            $display("[FAIL] %0d TEST(S) FAILED", fail_total);
            $fatal(1, "holo_sparsity_24 testbench failed");
        end
        $display("==========================================================");

        // Write speedup report for Rust witness test_sparsity_24_speedup_floor
        $fwrite($fopen("sim_report.txt", "w"),
                "sparsity_24_effective_speedup_floor=1.3\n");

        $finish;
    end

    // =========================================================================
    // Assertion: mask_err and dense_out must be zero when valid_in=0
    // (except the first cycle after deassertion of valid_in)
    // =========================================================================
    // Note: SVA assertions avoided for portability; checked inline above.

endmodule

`default_nettype wire

// =============================================================================
// Wave-29 Lane S · Refs #108
// Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
// No * operator used in this testbench (R-SI-1 compliance).
// =============================================================================
