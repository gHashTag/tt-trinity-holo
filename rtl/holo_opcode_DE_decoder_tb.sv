// holo_opcode_DE_decoder_tb.sv
// Testbench for TRI-27 ISA Opcode 0xDE: LOAD_PHYSICS_CONST
// Lane C' · L-DPC24 HOLOGRAPHIC v9
//
// Drives op=0xDE for const_id 0..3, verifies const_data matches ROM.
// Also verifies non-match behaviour (op != 0xDE → const_data = 0).
// R-SI-1: no `*` operator used anywhere in this file.
//
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>

`timescale 1ns/1ps

module holo_opcode_DE_decoder_tb;

    // DUT ports
    logic [7:0]  op;
    logic [3:0]  const_id;
    logic [4:0]  rd;
    logic        match_DE;
    logic [31:0] const_data;
    logic [4:0]  rd_out;

    // Expected ROM values (must mirror sacred_rom in DUT)
    // R-SI-1: no multiply operator
    logic [31:0] expected_rom [0:3];

    initial begin : ROM_REF_INIT
        expected_rom[0] = 32'h3F1E377A; // PHI_INV  : φ⁻¹
        expected_rom[1] = 32'h3E71BBD0; // GAMMA    : γ ≈ φ⁻³
        expected_rom[2] = 32'h3F1E377A; // C_LIGHT  : C anchor
        expected_rom[3] = 32'h3DA4F1BB; // G_GRAV   : G stub
    end

    // Instantiate DUT
    holo_opcode_DE_decoder dut (
        .op         (op),
        .const_id   (const_id),
        .rd         (rd),
        .match_DE   (match_DE),
        .const_data (const_data),
        .rd_out     (rd_out)
    );

    // ---------------------------------------------------------------
    // Test sequences
    // ---------------------------------------------------------------

    integer fail_count;
    integer i;

    initial begin : TEST_MAIN
        fail_count = 0;

        $display("=== holo_opcode_DE_decoder TB start ===");
        $display("TRI-27 ISA · Sacred range 0xD0..0xE0 · Opcode 0xDE LOAD_PHYSICS_CONST");

        // --------------------------------------------------------
        // Test 1: op=0xDE, const_id 0..3 → match_DE=1, correct data
        // --------------------------------------------------------
        op = 8'hDE;
        rd = 5'd7;

        for (i = 0; i < 4; i = i + 1) begin
            const_id = i[3:0];
            #10;

            if (!match_DE) begin
                $display("FAIL [const_id=%0d]: match_DE expected 1, got 0", i);
                fail_count = fail_count + 1;
            end

            if (const_data !== expected_rom[i]) begin
                $display("FAIL [const_id=%0d]: const_data expected 0x%08X, got 0x%08X",
                         i, expected_rom[i], const_data);
                fail_count = fail_count + 1;
            end

            if (rd_out !== rd) begin
                $display("FAIL [const_id=%0d]: rd_out expected %0d, got %0d",
                         i, rd, rd_out);
                fail_count = fail_count + 1;
            end

            $display("  const_id=%0d  match_DE=%b  const_data=0x%08X  rd_out=%0d  [%s]",
                     i, match_DE, const_data,
                     rd_out,
                     (const_data === expected_rom[i]) ? "OK" : "FAIL");
        end

        // --------------------------------------------------------
        // Test 2: op != 0xDE → match_DE=0, const_data=0
        // --------------------------------------------------------
        op = 8'hD0;
        const_id = 4'd0;
        rd = 5'd3;
        #10;

        if (match_DE !== 1'b0) begin
            $display("FAIL [no-match]: match_DE expected 0 for op=0xD0, got %b", match_DE);
            fail_count = fail_count + 1;
        end

        if (const_data !== 32'h0) begin
            $display("FAIL [no-match]: const_data expected 0 for op=0xD0, got 0x%08X", const_data);
            fail_count = fail_count + 1;
        end

        $display("  no-match test: op=0xD0  match_DE=%b  const_data=0x%08X  [%s]",
                 match_DE, const_data,
                 (match_DE === 1'b0 && const_data === 32'h0) ? "OK" : "FAIL");

        // --------------------------------------------------------
        // Final verdict
        // --------------------------------------------------------
        if (fail_count == 0) begin
            $display("R5-HONEST: opcode 0xDE LOAD_PHYSICS_CONST decoder PASS");
        end else begin
            $display("FAIL: %0d check(s) failed", fail_count);
            $finish(1);
        end

        $display("=== holo_opcode_DE_decoder TB end ===");
        $finish;
    end

endmodule : holo_opcode_DE_decoder_tb

// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
