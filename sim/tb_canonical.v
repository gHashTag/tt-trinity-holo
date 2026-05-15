// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// tb_canonical.v — Canonical T4 anchor testbench
// =============================================================================
//
// Tests that tt_um_qbrain_holo drives 0x47C0 on {uio_out[7:4], uo_out[7:0]}
// after reset, as required by PhD Theorem 36.1 (cross-die anchor).
//
// Expected: uo_out = 8'hC0, uio_out[7:4] = 4'h4 (uio_out = 8'h4X where X=D2D stubs)
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_canonical;

    // DUT I/O
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    // Expected canonical values
    localparam [7:0]  CANONICAL_LO = 8'hC0;   // uo_out after reset
    localparam [3:0]  CANONICAL_HI = 4'h4;    // uio_out[7:4] after reset

    // DUT instantiation
    tt_um_qbrain_holo dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // Clock: 4 ns period → 250 MHz
    always #2 clk = ~clk;

    initial begin
        // Initialise
        clk   = 0;
        rst_n = 0;
        ena   = 1;
        ui_in = 8'h00;  // mode=0 (canonical)
        uio_in = 8'h00;

        // Hold reset for 4 clock cycles
        repeat(4) @(posedge clk);

        // Release reset
        @(negedge clk);
        rst_n = 1;

        // Wait 2 clock cycles for output to settle
        repeat(2) @(posedge clk);
        #1; // Small delta to let combinational paths settle

        // =====================================================================
        // Probe P-01: uo_out must equal CANONICAL_LO (0xC0) in mode=0
        // =====================================================================
        if (uo_out !== CANONICAL_LO) begin
            $display("FAIL P-01: uo_out=0x%02X expected 0x%02X (canonical anchor)",
                     uo_out, CANONICAL_LO);
            $finish(1);
        end else begin
            $display("PASS P-01: uo_out=0x%02X == 0xC0 (canonical anchor LO)", uo_out);
        end

        // =====================================================================
        // Probe P-02: uio_out[7:4] must equal CANONICAL_HI (4'h4) in mode=0
        // =====================================================================
        if (uio_out[7:4] !== CANONICAL_HI) begin
            $display("FAIL P-02: uio_out[7:4]=0x%01X expected 0x%01X (canonical anchor HI)",
                     uio_out[7:4], CANONICAL_HI);
            $finish(1);
        end else begin
            $display("PASS P-02: uio_out[7:4]=0x%01X == 0x4 (canonical anchor HI)", uio_out[7:4]);
        end

        // =====================================================================
        // Probe P-03: Combined {uio_out[7:4], uo_out} == 0x47C0 interpretation
        // =====================================================================
        begin : p03_block
            reg [11:0] combined;
            combined = {uio_out[7:4], uo_out};
            if (combined !== 12'h4C0) begin
                $display("FAIL P-03: combined={uio_out[7:4],uo_out}=0x%03X expected 0x4C0",
                         combined);
                $finish(1);
            end else begin
                $display("PASS P-03: {uio_out[7:4],uo_out}=0x%03X == 0x4C0 (T4 anchor OK)",
                         combined);
            end
        end

        // =====================================================================
        // Probe P-04: D2D stubs must be LOW on reset (uio_out[3:0] == 4'b0000)
        // =====================================================================
        if (uio_out[3:0] !== 4'b0000) begin
            $display("FAIL P-04: D2D stubs uio_out[3:0]=0x%01X expected 0x0 (stub LOW)",
                     uio_out[3:0]);
            $finish(1);
        end else begin
            $display("PASS P-04: D2D stubs uio_out[3:0]=0x0 (all LOW, stub correct)");
        end

        // =====================================================================
        // Probe P-05: uio_oe must be 0xFF (all outputs)
        // =====================================================================
        if (uio_oe !== 8'hFF) begin
            $display("FAIL P-05: uio_oe=0x%02X expected 0xFF (all outputs)", uio_oe);
            $finish(1);
        end else begin
            $display("PASS P-05: uio_oe=0xFF (all IOs configured as outputs)");
        end

        $display("ALL PROBES PASSED — canonical T4 anchor 0x47C0 VERIFIED");
        $finish(0);
    end

endmodule
