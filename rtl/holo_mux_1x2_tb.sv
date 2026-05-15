// SPDX-License-Identifier: Apache-2.0
// holo_mux_1x2_tb.sv — minimal SystemVerilog testbench for holo_mux_1x2
//
// L-DPC24 Lane Y · tt-trinity-holo · TTSKY26c (multi-die)
// Anchor: φ²+φ⁻²=3   DOI 10.5281/zenodo.19227877
//
// Author: Vasilev Dmitrii <admin@t27.ai>
//
// Test plan:
//   T1: Apply die_a=0xAAAA…, die_b=0x5555…, sel=0 → expect dout==die_a (after 1 cycle)
//   T2: Keep same inputs, set sel=1 → expect dout==die_b (after 1 cycle)
//   T3: Assert reset clears dout to 0
//
// Simulation ends with $finish; on PASS or $fatal on FAIL.

`timescale 1ns/1ps
`default_nettype none

module holo_mux_1x2_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int unsigned WIDTH = 64;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic             clk;
    logic             rst_n;
    logic [WIDTH-1:0] die_a;
    logic [WIDTH-1:0] die_b;
    logic             sel;
    logic [WIDTH-1:0] dout;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    holo_mux_1x2 #(
        .WIDTH(WIDTH)
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .die_a (die_a),
        .die_b (die_b),
        .sel   (sel),
        .dout  (dout)
    );

    // -------------------------------------------------------------------------
    // Clock generation: 10 ns period → 100 MHz
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Stimulus & checks
    // -------------------------------------------------------------------------
    initial begin
        // --- Reset ---
        rst_n = 1'b0;
        die_a = {WIDTH{1'b1}};          // 0xFFFF…
        die_b = {WIDTH{1'b0}};          // 0x0000…
        sel   = 1'b0;
        @(posedge clk); #1;
        @(posedge clk); #1;

        // T3: confirm reset output is zero
        if (dout !== {WIDTH{1'b0}}) begin
            $fatal(1, "FAIL T3: dout expected 0 during reset, got %0h", dout);
        end

        // --- Release reset ---
        rst_n = 1'b1;

        // T1: sel=0 → expect die_a after 1 clock
        die_a = 64'hAAAA_AAAA_AAAA_AAAA;
        die_b = 64'h5555_5555_5555_5555;
        sel   = 1'b0;
        @(posedge clk); #1;

        if (dout !== die_a) begin
            $fatal(1, "FAIL T1: sel=0 expected dout=%0h (die_a), got %0h", die_a, dout);
        end
        $display("PASS T1: sel=0 → dout=die_a=0x%0h", dout);

        // T2: sel=1 → expect die_b after 1 clock
        sel = 1'b1;
        @(posedge clk); #1;

        if (dout !== die_b) begin
            $fatal(1, "FAIL T2: sel=1 expected dout=%0h (die_b), got %0h", die_b, dout);
        end
        $display("PASS T2: sel=1 → dout=die_b=0x%0h", dout);

        $display("ALL TESTS PASSED — holo_mux_1x2 bootstrap verified");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Simulation timeout guard (100 cycles)
    // -------------------------------------------------------------------------
    initial begin
        #1000;
        $fatal(1, "TIMEOUT: simulation exceeded 100 cycles without finishing");
    end

endmodule

`default_nettype wire
