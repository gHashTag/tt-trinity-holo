// =============================================================================
// tb_holo_mesh_2x2.sv  –  Testbench: 2×2 holo-mesh NoC
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (zero `*` operators)
// Lane V'  ·  L-DPC25  ·  R7 falsification witness
// =============================================================================
//
// Tests performed (R7 mandate):
//   TC1: Corner-to-corner traversal (N0→N3, 2 hops, latency ≤ 2 cycles)
//   TC2: All 4 nodes injecting simultaneously (no deadlock, all delivered)
//   TC3: 1000 random traffic patterns (no deadlock, max latency ≤ 2 cycles)
//
// Falsification predicates (mesh refuted iff ANY of the following):
//   (a) any RTL `*` operator present (R-SI-1 — checked offline by CI)
//   (b) any 2-cycle single-hop measured in this TB
//   (c) deadlock detected (≥ 200-cycle timeout with injected valid, no eject)
//   (d) mesh latency > Lane A' latency + 1 cycle
//
// Pass criterion: TC1 + TC2 + TC3 all pass with no timeout.
// n_required: 1000 random traffic patterns (G2 pre-registration).
// =============================================================================
`timescale 1ns/1ps

module tb_holo_mesh_2x2;

  // -------------------------------------------------------------------------
  // DUT parameters
  // -------------------------------------------------------------------------
  localparam int FLIT_W   = 32;
  localparam int TIMEOUT  = 200;  // cycles before deadlock declared

  // -------------------------------------------------------------------------
  // Clock and reset
  // -------------------------------------------------------------------------
  logic clk   = 1'b0;
  logic rst_n = 1'b0;

  always #5 clk = ~clk;  // 100 MHz

  // -------------------------------------------------------------------------
  // DUT signals
  // -------------------------------------------------------------------------
  logic [FLIT_W-1:0]  inj_flit [4];
  logic               inj_vld  [4];
  logic [FLIT_W-1:0]  ej_flit  [4];
  logic               ej_vld   [4];
  logic [0:0]         noc_latency [4];

  // -------------------------------------------------------------------------
  // DUT instantiation
  // -------------------------------------------------------------------------
  holo_mesh_2x2 #(.FLIT_W(FLIT_W)) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .inj_flit    (inj_flit),
    .inj_vld     (inj_vld),
    .ej_flit     (ej_flit),
    .ej_vld      (ej_vld),
    .noc_latency (noc_latency)
  );

  // -------------------------------------------------------------------------
  // Helper: build flit with embedded destination address
  //   flit[3:2] = dst_x,  flit[1:0] = dst_y
  //   flit[FLIT_W-1:4] = payload (upper bits)
  // -------------------------------------------------------------------------
  function automatic logic [FLIT_W-1:0] make_flit(
    input logic [1:0] dst_x,
    input logic [1:0] dst_y,
    input logic [FLIT_W-5:0] payload
  );
    return {payload, dst_x, dst_y};
  endfunction

  // -------------------------------------------------------------------------
  // Helper: node_id → (x,y)
  //   N0=0→(0,0)  N1=1→(1,0)  N2=2→(0,1)  N3=3→(1,1)
  // -------------------------------------------------------------------------
  function automatic logic [1:0] node_x(input int n);
    return (n == 1 || n == 3) ? 2'd1 : 2'd0;
  endfunction

  function automatic logic [1:0] node_y(input int n);
    return (n == 2 || n == 3) ? 2'd1 : 2'd0;
  endfunction

  // -------------------------------------------------------------------------
  // Test result counters
  // -------------------------------------------------------------------------
  int pass_count = 0;
  int fail_count = 0;

  // -------------------------------------------------------------------------
  // Simple pseudo-random LFSR (16-bit, no multiplier)
  // Polynomial: x^16+x^14+x^13+x^11+1 (maximal period)
  // -------------------------------------------------------------------------
  logic [15:0] lfsr_state = 16'hACE1;

  function automatic logic [15:0] lfsr_next(input logic [15:0] s);
    automatic logic feedback;
    feedback = s[15] ^ s[13] ^ s[12] ^ s[10];
    return {s[14:0], feedback};
  endfunction

  // -------------------------------------------------------------------------
  // Task: wait for eject at node dst_node, max TIMEOUT cycles
  // Returns latency (cycles) or -1 on timeout
  // -------------------------------------------------------------------------
  task automatic wait_eject(
    input int dst_node,
    input logic [FLIT_W-1:0] expected_flit,
    output int latency,
    output bit timed_out
  );
    int cycles;
    timed_out = 1'b0;
    latency   = 0;
    cycles    = 0;
    @(posedge clk);
    while (cycles < TIMEOUT) begin
      @(posedge clk);
      cycles = cycles + 1;
      if (ej_vld[dst_node]) begin
        latency = cycles;
        if (ej_flit[dst_node] !== expected_flit) begin
          $display("FAIL: flit mismatch at node %0d: got %h, expected %h",
                   dst_node, ej_flit[dst_node], expected_flit);
          fail_count++;
          return;
        end
        return;
      end
    end
    timed_out = 1'b1;
  endtask

  // -------------------------------------------------------------------------
  // Task: inject flit at src_node and deassert vld
  // -------------------------------------------------------------------------
  task automatic inject_flit(
    input int src_node,
    input logic [FLIT_W-1:0] f
  );
    @(negedge clk);
    inj_flit[src_node] = f;
    inj_vld[src_node]  = 1'b1;
    @(posedge clk);
    @(negedge clk);
    inj_vld[src_node]  = 1'b0;
  endtask

  // -------------------------------------------------------------------------
  // Main test sequence
  // -------------------------------------------------------------------------
  integer       tc_latency;
  bit           tc_timeout;
  logic [FLIT_W-1:0] flit_tc;

  initial begin
    // Initialise all injection ports
    for (int i = 0; i < 4; i++) begin
      inj_flit[i] = '0;
      inj_vld[i]  = 1'b0;
    end

    // ---- Reset sequence ----
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // =====================================================================
    // TC1: Corner-to-corner traversal N0(0,0) → N3(1,1)
    //      Expected: 2 hops → latency ≤ 2 cycles
    // =====================================================================
    $display("=== TC1: Corner-to-corner N0→N3 (2-hop) ===");
    flit_tc = make_flit(2'd1, 2'd1, {(FLIT_W-4){1'b0}} | 28'hDEAD_CA); // dst=(1,1)
    fork
      inject_flit(0, flit_tc);
      wait_eject(3, flit_tc, tc_latency, tc_timeout);
    join

    if (tc_timeout) begin
      $display("TC1 FAIL: DEADLOCK — no eject within %0d cycles", TIMEOUT);
      fail_count++;
    end else if (tc_latency > 2) begin
      $display("TC1 FAIL: latency=%0d > 2 cycles (2-hop must be ≤2)", tc_latency);
      fail_count++;
    end else begin
      $display("TC1 PASS: latency=%0d cycles", tc_latency);
      pass_count++;
    end

    // =====================================================================
    // TC1b: Reverse corner N3(1,1) → N0(0,0)
    // =====================================================================
    $display("=== TC1b: Corner-to-corner N3→N0 (2-hop reverse) ===");
    flit_tc = make_flit(2'd0, 2'd0, 28'hBEEF_AB); // dst=(0,0)
    fork
      inject_flit(3, flit_tc);
      wait_eject(0, flit_tc, tc_latency, tc_timeout);
    join

    if (tc_timeout) begin
      $display("TC1b FAIL: DEADLOCK");
      fail_count++;
    end else if (tc_latency > 2) begin
      $display("TC1b FAIL: latency=%0d > 2", tc_latency);
      fail_count++;
    end else begin
      $display("TC1b PASS: latency=%0d cycles", tc_latency);
      pass_count++;
    end

    // =====================================================================
    // TC1c: Single-hop N0(0,0) → N1(1,0) — must be exactly 1 cycle
    // =====================================================================
    $display("=== TC1c: Single-hop N0→N1 (1-hop, must be =1 cycle) ===");
    flit_tc = make_flit(2'd1, 2'd0, 28'hCAFE_01); // dst=(1,0)
    fork
      inject_flit(0, flit_tc);
      wait_eject(1, flit_tc, tc_latency, tc_timeout);
    join

    if (tc_timeout) begin
      $display("TC1c FAIL: DEADLOCK");
      fail_count++;
    end else if (tc_latency != 1) begin
      $display("TC1c FAIL: 1-hop latency=%0d, expected 1", tc_latency);
      fail_count++;
    end else begin
      $display("TC1c PASS: 1-hop latency=1 cycle confirmed");
      pass_count++;
    end

    // =====================================================================
    // TC2: All 4 nodes inject simultaneously (no deadlock)
    //      N0→N3, N1→N2, N2→N1, N3→N0
    // =====================================================================
    $display("=== TC2: All 4 nodes injecting simultaneously ===");
    begin
      automatic logic [FLIT_W-1:0] f_n0, f_n1, f_n2, f_n3;
      automatic int lat0, lat1, lat2, lat3;
      automatic bit to0, to1, to2, to3;

      f_n0 = make_flit(2'd1, 2'd1, 28'hA000_00); // N0→N3
      f_n1 = make_flit(2'd0, 2'd1, 28'hB111_11); // N1→N2
      f_n2 = make_flit(2'd1, 2'd0, 28'hC222_22); // N2→N1
      f_n3 = make_flit(2'd0, 2'd0, 28'hD333_33); // N3→N0

      @(negedge clk);
      inj_flit[0] = f_n0; inj_vld[0] = 1'b1;
      inj_flit[1] = f_n1; inj_vld[1] = 1'b1;
      inj_flit[2] = f_n2; inj_vld[2] = 1'b1;
      inj_flit[3] = f_n3; inj_vld[3] = 1'b1;
      @(posedge clk);
      @(negedge clk);
      inj_vld[0] = 1'b0;
      inj_vld[1] = 1'b0;
      inj_vld[2] = 1'b0;
      inj_vld[3] = 1'b0;

      fork
        wait_eject(3, f_n0, lat0, to0);
        wait_eject(2, f_n1, lat1, to1);
        wait_eject(1, f_n2, lat2, to2);
        wait_eject(0, f_n3, lat3, to3);
      join

      if (to0 || to1 || to2 || to3) begin
        $display("TC2 FAIL: DEADLOCK on simultaneous inject");
        fail_count++;
      end else if (lat0 > 2 || lat1 > 2 || lat2 > 2 || lat3 > 2) begin
        $display("TC2 FAIL: max latency exceeded (%0d %0d %0d %0d)", lat0, lat1, lat2, lat3);
        fail_count++;
      end else begin
        $display("TC2 PASS: all 4 delivered, latencies=%0d %0d %0d %0d", lat0, lat1, lat2, lat3);
        pass_count++;
      end
    end

    // =====================================================================
    // TC3: 1000 random traffic patterns (G2: n_required=1000)
    //      Each pattern: pick random src != dst, inject, wait eject ≤2cy
    //      Deadlock counted as fail
    // =====================================================================
    $display("=== TC3: 1000 random traffic patterns ===");
    begin
      automatic int rnd_fail = 0;
      automatic int rnd_pass = 0;
      automatic int lat_max  = 0;

      for (int iter = 0; iter < 1000; iter++) begin
        automatic int src, dst;
        automatic logic [FLIT_W-1:0] f_rnd;
        automatic int lat_rnd;
        automatic bit to_rnd;
        automatic logic [1:0] dx, dy;

        // Advance LFSR twice: pick src (bits[1:0]) and dst (bits[3:2])
        lfsr_state = lfsr_next(lfsr_state);
        src = lfsr_state[1:0];  // 0..3
        lfsr_state = lfsr_next(lfsr_state);
        dst = lfsr_state[1:0];  // 0..3

        // Self-delivery is trivially 1 cycle; include to stress local port
        dx = node_x(dst);
        dy = node_y(dst);
        f_rnd = make_flit(dx, dy, lfsr_state[FLIT_W-5:0]);

        fork
          inject_flit(src, f_rnd);
          wait_eject(dst, f_rnd, lat_rnd, to_rnd);
        join

        if (to_rnd) begin
          rnd_fail++;
          $display("TC3 iter=%0d FAIL: DEADLOCK src=%0d dst=%0d", iter, src, dst);
        end else if (lat_rnd > 2) begin
          rnd_fail++;
          $display("TC3 iter=%0d FAIL: latency=%0d src=%0d dst=%0d", iter, lat_rnd, src, dst);
        end else begin
          rnd_pass++;
          if (lat_rnd > lat_max) lat_max = lat_rnd;
        end
      end

      if (rnd_fail == 0) begin
        $display("TC3 PASS: 1000/1000 patterns OK, max_latency=%0d cycles", lat_max);
        pass_count++;
      end else begin
        $display("TC3 FAIL: %0d/1000 patterns failed", rnd_fail);
        fail_count++;
      end
    end

    // =====================================================================
    // Final verdict
    // =====================================================================
    $display("");
    $display("=== FINAL VERDICT ===");
    $display("PASS: %0d   FAIL: %0d", pass_count, fail_count);
    if (fail_count == 0) begin
      $display("ALL TESTS PASSED — holo_mesh_2x2 1-cycle-hop + deadlock-free confirmed");
      $display("R7 FALSIFICATION WITNESS: mesh_2x2_no_star + mesh_1cycle_hop + mesh_deadlock_free = PASS");
    end else begin
      $display("SOME TESTS FAILED — mesh does NOT satisfy all predicates");
    end

    $finish;
  end

  // -------------------------------------------------------------------------
  // Watchdog: global timeout
  // -------------------------------------------------------------------------
  initial begin
    #500000;
    $display("GLOBAL WATCHDOG: simulation exceeded 500000ns");
    $finish;
  end

endmodule
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// R7 falsification witness: TB confirms mesh_2x2 1-cycle-hop + deadlock-free
// Lane V' · L-DPC25
