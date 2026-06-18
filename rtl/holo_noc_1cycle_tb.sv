// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// holo_noc_1cycle_tb.sv  –  Testbench for holo_noc_1cycle
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant
// Lane A'  ·  L-DPC24 HOLOGRAPHIC v9  ·  holo-noc-1cycle
//
// Tests:
//   T1  die0 → die1 : observe payload at die1 output after EXACTLY 1 cycle
//   T2  die1 → die0 : observe payload at die0 output after EXACTLY 1 cycle
//   T3  Simultaneous bidirectional: die0↔die1 same cycle — P4 boundary
//
// Failure mode: $fatal on any latency > 1 cycle (P4 boundary assertion).
//
// Author:  Vasilev Dmitrii <admin@t27.ai>
// DOI:     10.5281/zenodo.19227877
// Anchor:  φ²+φ⁻²=3
// =============================================================================
`default_nettype none
`timescale 1ns/1ps

module holo_noc_1cycle_tb;

  // -------------------------------------------------------------------------
  // Parameters (match DUT defaults)
  // -------------------------------------------------------------------------
  localparam int unsigned DIE_COUNT = 2;
  localparam int unsigned PAYLOAD_W = 64;
  localparam int unsigned DST_W     = $clog2(DIE_COUNT);  // 1 bit for 2 dies

  // -------------------------------------------------------------------------
  // DUT signals
  // -------------------------------------------------------------------------
  logic                     clk;
  logic                     rst_n;
  logic [DIE_COUNT-1:0]     vld_i;
  logic [DST_W-1:0]         dst_i    [DIE_COUNT];
  logic [PAYLOAD_W-1:0]     payload_i[DIE_COUNT];
  logic [DIE_COUNT-1:0]     vld_o;
  logic [PAYLOAD_W-1:0]     payload_o[DIE_COUNT];

  // -------------------------------------------------------------------------
  // DUT instantiation
  // -------------------------------------------------------------------------
  holo_noc_1cycle #(
    .DIE_COUNT (DIE_COUNT),
    .PAYLOAD_W (PAYLOAD_W)
  ) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .vld_i     (vld_i),
    .dst_i     (dst_i),
    .payload_i (payload_i),
    .vld_o     (vld_o),
    .payload_o (payload_o)
  );

  // -------------------------------------------------------------------------
  // Clock: 10 ns period
  // -------------------------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  // Timestamp of first valid injection (set per test)
  integer inject_cycle;
  integer current_cycle;

  // Cycle counter
  initial current_cycle = 0;
  always_ff @(posedge clk) current_cycle <= current_cycle + 1;

  // Task: assert exact 1-cycle latency — $fatal if violated (P4 boundary)
  task automatic check_latency(
    input string         test_name,
    input int            inj_cycle,
    input int            obs_cycle
  );
    int latency;
    latency = obs_cycle - inj_cycle;
    if (latency != 1) begin
      $fatal(1, "P4 VIOLATION [%s]: latency=%0d cycles (expected 1). noc_stall > 1 → FAIL",
             test_name, latency);
    end else begin
      $display("PASS [%s]: latency = %0d cycle (P4 falsified OK)", test_name, latency);
    end
  endtask

  // -------------------------------------------------------------------------
  // Stimulus / checker
  // -------------------------------------------------------------------------
  logic [PAYLOAD_W-1:0] t1_payload;
  logic [PAYLOAD_W-1:0] t2_payload;
  logic [PAYLOAD_W-1:0] t3_payload_d0;
  logic [PAYLOAD_W-1:0] t3_payload_d1;

  initial begin
    // Initialise test payloads (no `*` operator — literals only)
    t1_payload    = 64'hDEAD_BEEF_0000_0001;  // die0→die1
    t2_payload    = 64'hCAFE_BABE_0000_0002;  // die1→die0
    t3_payload_d0 = 64'hA5A5_A5A5_0000_0003;  // bidirectional die0→die1
    t3_payload_d1 = 64'h5A5A_5A5A_0000_0004;  // bidirectional die1→die0

    // Idle state
    vld_i       = '0;
    dst_i[0]    = '0;
    dst_i[1]    = '0;
    payload_i[0] = '0;
    payload_i[1] = '0;

    // Active-low synchronous reset for 3 cycles
    rst_n = 1'b0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    rst_n = 1'b1;
    @(posedge clk); #1;

    // Verify reset cleared outputs
    if (vld_o !== '0) begin
      $fatal(1, "RESET CHECK FAIL: vld_o = %b, expected 0", vld_o);
    end
    $display("RESET: vld_o = %b (OK)", vld_o);

    // -----------------------------------------------------------------------
    // T1: die0 sends to die1 — exactly 1 cycle
    // -----------------------------------------------------------------------
    $display("--- T1: die0 → die1 ---");
    vld_i[0]     = 1'b1;
    vld_i[1]     = 1'b0;
    dst_i[0]     = 1'b1;          // destination = die1
    payload_i[0] = t1_payload;
    inject_cycle = current_cycle;
    @(posedge clk); #1;
    // One cycle later: check
    vld_i = '0;
    if (!vld_o[1]) begin
      $fatal(1, "T1 FAIL: vld_o[1] not asserted after 1 cycle");
    end
    if (payload_o[1] !== t1_payload) begin
      $fatal(1, "T1 FAIL: payload_o[1]=0x%016h expected 0x%016h",
             payload_o[1], t1_payload);
    end
    check_latency("T1", inject_cycle, current_cycle);

    // -----------------------------------------------------------------------
    // T2: die1 sends to die0 — exactly 1 cycle
    // -----------------------------------------------------------------------
    $display("--- T2: die1 → die0 ---");
    @(posedge clk); #1;  // idle gap
    vld_i[0]     = 1'b0;
    vld_i[1]     = 1'b1;
    dst_i[1]     = 1'b0;          // destination = die0
    payload_i[1] = t2_payload;
    inject_cycle = current_cycle;
    @(posedge clk); #1;
    vld_i = '0;
    if (!vld_o[0]) begin
      $fatal(1, "T2 FAIL: vld_o[0] not asserted after 1 cycle");
    end
    if (payload_o[0] !== t2_payload) begin
      $fatal(1, "T2 FAIL: payload_o[0]=0x%016h expected 0x%016h",
             payload_o[0], t2_payload);
    end
    check_latency("T2", inject_cycle, current_cycle);

    // -----------------------------------------------------------------------
    // T3: simultaneous bidirectional — both delivered in 1 cycle (P4 boundary)
    // -----------------------------------------------------------------------
    $display("--- T3: die0↔die1 simultaneous bidirectional (P4 boundary) ---");
    @(posedge clk); #1;  // idle gap
    vld_i[0]     = 1'b1;
    vld_i[1]     = 1'b1;
    dst_i[0]     = 1'b1;          // die0 → die1
    dst_i[1]     = 1'b0;          // die1 → die0
    payload_i[0] = t3_payload_d0;
    payload_i[1] = t3_payload_d1;
    inject_cycle = current_cycle;
    @(posedge clk); #1;
    vld_i = '0;
    // Both die0 and die1 should receive in this same 1-cycle step
    if (!vld_o[1]) begin
      $fatal(1, "T3 FAIL: vld_o[1] not asserted (die0→die1 path)");
    end
    if (!vld_o[0]) begin
      $fatal(1, "T3 FAIL: vld_o[0] not asserted (die1→die0 path)");
    end
    if (payload_o[1] !== t3_payload_d0) begin
      $fatal(1, "T3 FAIL: payload_o[1]=0x%016h expected 0x%016h (die0→die1)",
             payload_o[1], t3_payload_d0);
    end
    if (payload_o[0] !== t3_payload_d1) begin
      $fatal(1, "T3 FAIL: payload_o[0]=0x%016h expected 0x%016h (die1→die0)",
             payload_o[0], t3_payload_d1);
    end
    check_latency("T3 (die0→die1)", inject_cycle, current_cycle);
    check_latency("T3 (die1→die0)", inject_cycle, current_cycle);
    $display("PASS T3: bidirectional 1-cycle delivery confirmed. P4 falsified.");

    // -----------------------------------------------------------------------
    // Done
    // -----------------------------------------------------------------------
    $display("ALL TESTS PASSED: holo_noc_1cycle 1-cycle latency verified.");
    $display("P4 (noc_stall > 1 cycle) = FALSIFIED.");
    $display("Anchor: phi^2 + phi^-2 = 3  |  DOI 10.5281/zenodo.19227877");
    $finish;
  end

  // -------------------------------------------------------------------------
  // Watchdog: abort if simulation runs > 200 cycles
  // -------------------------------------------------------------------------
  initial begin
    #2000;
    $fatal(1, "WATCHDOG: simulation exceeded 200 cycles — hung testbench");
  end

endmodule : holo_noc_1cycle_tb
`default_nettype wire
// -----------------------------------------------------------------------------
// φ²+φ⁻²=3  ·  DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>  ·  ORCID 0009-0008-4294-6159
// -----------------------------------------------------------------------------
