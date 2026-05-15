// =============================================================================
// holo_bitrom_bank_tb.sv — Testbench for holo_bitrom_bank
// Lane W · L-DPC25 Wave-28 · OP_BITROM_READ = 0xE0
// =============================================================================
//
// Tests:
//   1. Forward read at addresses 0, 1, 2, 255
//      Expected: weight_out == addr ^ 0x5A
//   2. Reverse read at addresses 0, 1, 2, 255
//      Expected: weight_out == (255 - addr) ^ 0x5A
//   3. 1-cycle latency verified
//   4. Opcode gate — non-0xE0 opcode suppresses output
//
// On success prints: LANE W BITROM TEST PASS
// On failure prints: LANE W BITROM TEST FAIL at step <n>
//
// Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module holo_bitrom_bank_tb;

    // -----------------------------------------------------------------------
    // DUT instance
    // -----------------------------------------------------------------------
    localparam integer ROM_DEPTH  = 256;
    localparam integer WORD_WIDTH = 8;
    localparam integer ADDR_WIDTH = 8; // $clog2(256)

    reg                  clk;
    reg                  rst_n;
    reg                  valid_in;
    reg  [7:0]           opcode;
    reg  [ADDR_WIDTH-1:0] addr;
    reg                  direction;
    wire                 valid_out;
    wire [WORD_WIDTH-1:0] weight_out;

    holo_bitrom_bank #(
        .ROM_DEPTH  (ROM_DEPTH),
        .WORD_WIDTH (WORD_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (valid_in),
        .opcode     (opcode),
        .addr       (addr),
        .direction  (direction),
        .valid_out  (valid_out),
        .weight_out (weight_out)
    );

    // -----------------------------------------------------------------------
    // Clock generation — 10 ns period
    // -----------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Test stimulus
    // -----------------------------------------------------------------------
    integer fail_count;
    integer step;
    reg [7:0] expected;

    // Addresses under test
    localparam [7:0] A0  = 8'd0;
    localparam [7:0] A1  = 8'd1;
    localparam [7:0] A2  = 8'd2;
    localparam [7:0] A255 = 8'd255;

    task apply_and_check;
        input [ADDR_WIDTH-1:0] test_addr;
        input                  test_dir;
        input [WORD_WIDTH-1:0] test_expected;
        input integer          test_step;
        begin
            // Apply inputs
            valid_in  = 1'b1;
            opcode    = 8'hE0;
            addr      = test_addr;
            direction = test_dir;
            @(posedge clk);
            // 1-cycle latency: output valid on the next rising edge
            #1; // small delta after clock edge
            if (!valid_out) begin
                $display("FAIL step %0d: valid_out not asserted (addr=%0d dir=%0d)", test_step, test_addr, test_dir);
                fail_count = fail_count + 1;
            end else if (weight_out !== test_expected) begin
                $display("FAIL step %0d: addr=%0d dir=%0d expected=0x%02h got=0x%02h",
                         test_step, test_addr, test_dir, test_expected, weight_out);
                fail_count = fail_count + 1;
            end
            // Deassert for one cycle between tests
            valid_in = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        fail_count = 0;
        step       = 0;

        // Reset
        rst_n    = 1'b0;
        valid_in = 1'b0;
        opcode   = 8'h00;
        addr     = 8'h00;
        direction = 1'b0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ---------------------------------------------------------------
        // Section 1: Forward direction (direction = 0)
        //   Expected: weight_out[i] = i ^ 0x5A
        // ---------------------------------------------------------------
        step = step + 1;
        apply_and_check(A0,   1'b0, A0   ^ 8'h5A, step); // 0 ^ 0x5A = 0x5A
        step = step + 1;
        apply_and_check(A1,   1'b0, A1   ^ 8'h5A, step); // 1 ^ 0x5A = 0x5B
        step = step + 1;
        apply_and_check(A2,   1'b0, A2   ^ 8'h5A, step); // 2 ^ 0x5A = 0x58
        step = step + 1;
        apply_and_check(A255, 1'b0, A255 ^ 8'h5A, step); // 255 ^ 0x5A = 0xA5

        // ---------------------------------------------------------------
        // Section 2: Reverse direction (direction = 1)
        //   Expected: weight_out[i] = (255 - i) ^ 0x5A
        // ---------------------------------------------------------------
        step = step + 1;
        apply_and_check(A0,   1'b1, (8'd255 - A0  ) ^ 8'h5A, step); // rom[255] = 255^0x5A
        step = step + 1;
        apply_and_check(A1,   1'b1, (8'd255 - A1  ) ^ 8'h5A, step); // rom[254]
        step = step + 1;
        apply_and_check(A2,   1'b1, (8'd255 - A2  ) ^ 8'h5A, step); // rom[253]
        step = step + 1;
        apply_and_check(A255, 1'b1, (8'd255 - A255) ^ 8'h5A, step); // rom[0] = 0^0x5A

        // ---------------------------------------------------------------
        // Section 3: Opcode gate — non-0xE0 should produce valid_out=0
        // ---------------------------------------------------------------
        valid_in  = 1'b1;
        opcode    = 8'hDE; // Lane C' opcode — should NOT trigger
        addr      = A0;
        direction = 1'b0;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0) begin
            $display("FAIL opcode gate: valid_out asserted for opcode 0xDE (expected 0)");
            fail_count = fail_count + 1;
        end
        valid_in = 1'b0;
        @(posedge clk);

        // ---------------------------------------------------------------
        // Result
        // ---------------------------------------------------------------
        if (fail_count == 0) begin
            $display("LANE W BITROM TEST PASS");
        end else begin
            $display("LANE W BITROM TEST FAIL — %0d error(s)", fail_count);
        end

        #20;
        $finish;
    end

endmodule

`default_nettype wire
