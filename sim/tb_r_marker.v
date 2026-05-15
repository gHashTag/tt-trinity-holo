// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// tb_r_marker.v — R-marker ROM stub testbench
// =============================================================================
//
// Tests that all 4 R-marker slots read back as ZERO.
// This is the PLACEHOLDER state (R5-HONEST: TODO revise when measured).
//
// When a physics constant is measured and written to a slot, this testbench
// must be updated with the measured value BEFORE tape-out (R-marker revision
// protocol, Popper Appendix B, PhD monograph DOI 10.5281/zenodo.19227877).
//
// Slots under test:
//   Slot 0: C_quantum_consciousness — expected 0x0000 (UNMEASURED)
//   Slot 1: k_dark_coupling         — expected 0x0000 (UNMEASURED)
//   Slot 2: τ_microtubule           — expected 0x0000 (UNMEASURED)
//   Slot 3: ζ_neural_zeta           — expected 0x0000 (UNMEASURED)
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_r_marker;

    // ROM I/O
    reg        clk;
    reg        rst_n;
    reg  [1:0] addr;
    wire [15:0] data_out;

    // R-marker ROM instantiation (standalone test)
    r_marker_rom dut_rom (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (addr),
        .data_out (data_out)
    );

    // Clock: 4 ns period → 250 MHz
    always #2 clk = ~clk;

    integer slot;
    reg test_failed;

    initial begin
        // Initialise
        clk        = 0;
        rst_n      = 0;
        addr       = 2'b00;
        test_failed = 0;

        // Reset
        repeat(4) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // =====================================================================
        // Read all 4 R-marker slots, assert they are zero
        // R5-HONEST: These are PLACEHOLDER stubs — expected 0x0000 until measured.
        // TODO: Update expected values when each constant is measured.
        // =====================================================================
        for (slot = 0; slot < 4; slot = slot + 1) begin
            addr = slot[1:0];
            @(posedge clk);
            #1; // Delta delay for registered output

            @(posedge clk);
            #1;

            if (data_out !== 16'h0000) begin
                $display("FAIL slot=%0d: data_out=0x%04X expected 0x0000 (UNMEASURED placeholder)",
                         slot, data_out);
                test_failed = 1;
            end else begin
                case (slot)
                    0: $display("PASS slot=0 C_quantum_consciousness=0x%04X (UNMEASURED stub OK)", data_out);
                    1: $display("PASS slot=1 k_dark_coupling=0x%04X (UNMEASURED stub OK)", data_out);
                    2: $display("PASS slot=2 tau_microtubule=0x%04X (UNMEASURED stub OK)", data_out);
                    3: $display("PASS slot=3 zeta_neural_zeta=0x%04X (UNMEASURED stub OK)", data_out);
                endcase
            end
        end

        if (test_failed) begin
            $display("FAIL: R-marker ROM has non-zero stub values — check r_marker_rom.v");
            $finish(1);
        end else begin
            $display("ALL SLOTS ZERO — R-marker ROM placeholder state VERIFIED (R5-HONEST)");
            $display("NOTE: Update this testbench when constants are measured.");
            $finish(0);
        end
    end

endmodule
