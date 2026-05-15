// =============================================================================
// holo_lut_pe_tb.sv  —  Testbench for holo_lut_pe
// Lane V · L-DPC25 Wave-28 · TRI-27 ISA opcode OP_LUT_LOOKUP = 0xDF
// =============================================================================
//
// Tests:
//   1. Initialize LUT with pattern: lut[i] = i ^ 8'hA5  (no multiply; XOR only)
//   2. Drive 16 addresses, check output matches expected value
//   3. Verify 1-cycle latency (valid_out follows valid_in by exactly 1 cycle)
//   4. Check valid_out de-asserts on opcode mismatch
//   Print "LANE V LUT PE TEST PASS" on success.
//
// Tracking issue: Refs #17
// Anchor: phi^2 + phi^-2 = 3
// =============================================================================

`default_nettype none
`timescale 1ns / 1ps

module holo_lut_pe_tb;

    // -------------------------------------------------------------------------
    // Parameters matching DUT defaults
    // -------------------------------------------------------------------------
    localparam int unsigned LUT_WIDTH  = 4;
    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned LUT_DEPTH  = 1 << LUT_WIDTH;  // 16; shift, no *

    localparam logic [7:0] OP_LUT_LOOKUP = 8'hDF;
    localparam logic [7:0] OP_OTHER      = 8'hAB;  // any non-matching opcode

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    logic                       valid_in;
    logic [7:0]                 opcode;
    logic [LUT_WIDTH-1:0]       addr;
    logic [DATA_WIDTH-1:0]      data_in;
    logic                       lut_write_en;
    logic [LUT_WIDTH-1:0]       lut_write_addr;
    logic [DATA_WIDTH-1:0]      lut_write_data;
    logic                       valid_out;
    logic [DATA_WIDTH-1:0]      data_out;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    holo_lut_pe #(
        .LUT_WIDTH  (LUT_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .opcode         (opcode),
        .addr           (addr),
        .data_in        (data_in),
        .lut_write_en   (lut_write_en),
        .lut_write_addr (lut_write_addr),
        .lut_write_data (lut_write_data),
        .valid_out      (valid_out),
        .data_out       (data_out)
    );

    // -------------------------------------------------------------------------
    // Clock: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test counters
    // -------------------------------------------------------------------------
    int pass_count;
    int fail_count;

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------
    task automatic tick;
        @(posedge clk); #1;
    endtask

    task automatic assert_eq(
        input logic [DATA_WIDTH-1:0] actual,
        input logic [DATA_WIDTH-1:0] expected,
        input string                  msg
    );
        if (actual !== expected) begin
            $display("FAIL [%s]: got 0x%02h, expected 0x%02h", msg, actual, expected);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    task automatic assert_bit(
        input logic actual,
        input logic expected,
        input string msg
    );
        if (actual !== expected) begin
            $display("FAIL [%s]: got %0b, expected %0b", msg, actual, expected);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        pass_count    = 0;
        fail_count    = 0;

        // Defaults
        rst_n         = 1'b0;
        valid_in      = 1'b0;
        opcode        = OP_LUT_LOOKUP;
        addr          = '0;
        data_in       = '0;
        lut_write_en  = 1'b0;
        lut_write_addr = '0;
        lut_write_data = '0;

        // ---------------------------------------------------------------
        // Reset
        // ---------------------------------------------------------------
        repeat (3) tick;
        rst_n = 1'b1;
        tick;

        // ---------------------------------------------------------------
        // Phase 1: Program LUT with pattern lut[i] = i ^ 8'hA5
        // (XOR only — no multiply)
        // ---------------------------------------------------------------
        for (int i = 0; i < LUT_DEPTH; i++) begin
            lut_write_en   = 1'b1;
            lut_write_addr = LUT_WIDTH'(i);
            lut_write_data = DATA_WIDTH'(i) ^ 8'hA5;
            tick;
        end
        lut_write_en = 1'b0;
        tick;

        // ---------------------------------------------------------------
        // Phase 2: Drive all 16 addresses, check output matches i ^ 0xA5
        //          Verify 1-cycle latency and valid_out tracking
        // ---------------------------------------------------------------
        for (int i = 0; i < LUT_DEPTH; i++) begin
            valid_in = 1'b1;
            opcode   = OP_LUT_LOOKUP;
            addr     = LUT_WIDTH'(i);
            tick;  // valid_in presented at posedge; output captured next cycle

            // Check: valid_out must follow valid_in by 1 cycle
            assert_bit(valid_out, 1'b1, $sformatf("valid_out addr=%0d", i));

            // Check: data_out must equal i ^ 0xA5
            assert_eq(data_out, DATA_WIDTH'(i) ^ 8'hA5, $sformatf("data_out addr=%0d", i));
        end
        valid_in = 1'b0;
        tick;

        // ---------------------------------------------------------------
        // Phase 3: Check valid_out de-asserts on opcode mismatch
        // ---------------------------------------------------------------
        valid_in = 1'b1;
        opcode   = OP_OTHER;
        addr     = 4'h3;
        tick;
        assert_bit(valid_out, 1'b0, "valid_out suppressed on wrong opcode");
        valid_in = 1'b0;
        opcode   = OP_LUT_LOOKUP;
        tick;

        // ---------------------------------------------------------------
        // Phase 4: Check valid_out de-asserts when valid_in low
        // ---------------------------------------------------------------
        valid_in = 1'b0;
        opcode   = OP_LUT_LOOKUP;
        addr     = 4'h7;
        tick;
        assert_bit(valid_out, 1'b0, "valid_out low when valid_in low");

        // ---------------------------------------------------------------
        // Result
        // ---------------------------------------------------------------
        if (fail_count == 0) begin
            $display("LANE V LUT PE TEST PASS  (checks=%0d, pass=%0d, fail=0)",
                     pass_count, pass_count);
        end else begin
            $display("LANE V LUT PE TEST FAIL  (pass=%0d, fail=%0d)",
                     pass_count, fail_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
