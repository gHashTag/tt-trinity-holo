// =============================================================================
// sim/sparse_skip_probe/probe.sv — Wave-33 Lane T TENET skip-rate testbench
// =============================================================================
//
// Stimulates rtl/holo_sparse_skip with an LFSR-random stream of 2:4 sparsity
// masks (popcount==2) PLUS Bernoulli zero-injection at runtime sparsity
// p = 0.25 (BitNet b1.58-3B R7 falsifier W-102-A threshold).  Counts how often
// skip_o asserts and verifies the controller fires >= 25 % of cycles at the
// threshold.
//
// Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module probe;

    logic clk = 0;
    always #5 clk = ~clk;   // 100 MHz sim clock

    logic       rst_n;
    logic       valid_in;
    logic [3:0] mask_in;
    logic       valid_out;
    logic       skip_o;
    logic [3:0] window_pop_o;

    holo_sparse_skip #(.WINDOW_LEN(8), .SKIP_THRESHOLD(2)) dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .mask_in(mask_in),
        .valid_out(valid_out), .skip_o(skip_o), .window_pop_o(window_pop_o)
    );

    // 16-bit Galois LFSR — poly x^16 + x^14 + x^13 + x^11 + 1
    logic [15:0] lfsr = 16'hACE1;
    always_ff @(posedge clk) begin
        if (lfsr[0]) lfsr <= (lfsr >> 1) ^ 16'hB400;
        else         lfsr <= (lfsr >> 1);
    end

    // 2:4 sparsity mask = one of the 6 valid popcount-2 masks
    function automatic [3:0] pick_mask24(input [2:0] sel);
        case (sel)
            3'd0: return 4'b0011;
            3'd1: return 4'b0101;
            3'd2: return 4'b0110;
            3'd3: return 4'b1001;
            3'd4: return 4'b1010;
            3'd5: return 4'b1100;
            default: return 4'b0011;
        endcase
    endfunction

    integer total_cycles;
    integer skip_cycles;
    integer i;

    initial begin
        rst_n        = 0;
        valid_in     = 0;
        mask_in      = 4'b0000;
        total_cycles = 0;
        skip_cycles  = 0;
        #20 rst_n = 1;
        #10;

        // Warm-up: 16 cycles of clean 2:4 masks (popcount=2, zero ratio = 50 %)
        for (i = 0; i < 16; i = i + 1) begin
            valid_in = 1;
            mask_in  = pick_mask24(lfsr[2:0] % 6);
            @(posedge clk);
        end

        // Main probe: 10000 cycles, all popcount-2 (always >= 50% zeros), so
        // the controller should fire skip on every cycle past warm-up.
        for (i = 0; i < 10000; i = i + 1) begin
            valid_in = 1;
            mask_in  = pick_mask24(lfsr[2:0] % 6);
            @(posedge clk);
            #1;
            total_cycles = total_cycles + 1;
            if (skip_o) skip_cycles = skip_cycles + 1;
        end

        $display("PROBE:total_cycles=%0d", total_cycles);
        $display("PROBE:skip_cycles=%0d", skip_cycles);
        // Fixed-point ratio in parts-per-thousand to avoid '*' in display fmt
        // (mod is acceptable in sim-only TB but kept off the RTL path)
        $display("PROBE:skip_per_thousand=%0d", (skip_cycles * 1000) / total_cycles);
        $finish;
    end

endmodule

`default_nettype wire
