// =============================================================================
// holo_noc_2x2_mesh_tb.sv  –  Testbench for 2×2 mesh NoC (Lane V')
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (ZERO `*` operator)
// Lane V'  ·  L-DPC25  ·  Wave-28
// =============================================================================
// Port convention (flat packed, LSB = die0):
//   flit_in [127:0]  — die0=[31:0], die1=[63:32], die2=[95:64], die3=[127:96]
//   dest_in [7:0]    — die0=[1:0],  die1=[3:2],   die2=[5:4],   die3=[7:6]
//   vld_in  [3:0]    — die0=[0], die1=[1], die2=[2], die3=[3]
//
// Test cases:
//   TC1  die0 → die3 (opposite corner, 2-hop)
//   TC2  die0 → die1 (E-neighbour, 1-hop)
//   TC3  4 simultaneous unicast 1-hop broadcasts (zero contention)
//   TC4  hop_latency_cycles == 1
//
// Timing: inject at negedge N; sample at posedge N+1 (#1 after edge) while
// inputs are still asserted.  1-hop flit appears at posedge N+1.
// 2-hop flit: die0 injects at negedge N; die1 register auto-forwards;
//             sample die3 at posedge N+2 (clear die0 injection at negedge N+1).
// =============================================================================
`timescale 1ns/1ps

module holo_noc_2x2_mesh_tb;

  logic         clk;
  logic         rst_n;
  logic [127:0] flit_in;
  logic [7:0]   dest_in;
  logic [3:0]   vld_in;
  logic [127:0] flit_out;
  logic [3:0]   vld_out;
  logic [0:0]   hop_latency_cycles;

  holo_noc_2x2_mesh #(.FLIT_W(32), .DIES(4)) dut (
    .clk               (clk),
    .rst_n             (rst_n),
    .flit_in           (flit_in),
    .dest_in           (dest_in),
    .vld_in            (vld_in),
    .flit_out          (flit_out),
    .vld_out           (vld_out),
    .hop_latency_cycles(hop_latency_cycles)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Set a single die's flit/dest/valid using literal bit slices
  // d must be a constant 0..3 at elaboration or a runtime integer;
  // for task calls we pass literal indices directly to avoid `*`.
  task automatic set_die0(input logic [31:0] f, input logic [1:0] dst, input logic v);
    flit_in[31:0]  = f; dest_in[1:0] = dst; vld_in[0] = v;
  endtask
  task automatic set_die1(input logic [31:0] f, input logic [1:0] dst, input logic v);
    flit_in[63:32] = f; dest_in[3:2] = dst; vld_in[1] = v;
  endtask
  task automatic set_die2(input logic [31:0] f, input logic [1:0] dst, input logic v);
    flit_in[95:64] = f; dest_in[5:4] = dst; vld_in[2] = v;
  endtask
  task automatic set_die3(input logic [31:0] f, input logic [1:0] dst, input logic v);
    flit_in[127:96] = f; dest_in[7:6] = dst; vld_in[3] = v;
  endtask

  task automatic clear_all;
    flit_in = 128'd0; dest_in = 8'd0; vld_in = 4'd0;
  endtask

  // Accessors using literal slices (no `*`)
  function [31:0] gfo0; gfo0 = flit_out[31:0];   endfunction
  function [31:0] gfo1; gfo1 = flit_out[63:32];  endfunction
  function [31:0] gfo2; gfo2 = flit_out[95:64];  endfunction
  function [31:0] gfo3; gfo3 = flit_out[127:96]; endfunction

  integer pass_count, fail_count;

  task automatic chk(input string name, input logic cond);
    if (cond) begin $display("  PASS: %s", name); pass_count = pass_count + 1; end
    else      begin $display("  FAIL: %s", name); fail_count = fail_count + 1; end
  endtask

  initial begin
    pass_count = 0; fail_count = 0;
    rst_n = 0; flit_in = 0; dest_in = 0; vld_in = 0;
    repeat(4) @(posedge clk);
    @(negedge clk); rst_n = 1;
    @(posedge clk); #1;

    // ------------------------------------------------------------------
    // TC4: hop_latency_cycles == 1
    // ------------------------------------------------------------------
    chk("TC4 hop_latency_cycles==1", hop_latency_cycles == 1'b1);

    // ------------------------------------------------------------------
    // TC2: die0 → die1 (1-hop, E-neighbour)
    //   XY: (0,0)→(0,1): col differs → next_hop=(0,1)=die1
    //   Inject at negedge; sample at posedge+1 with inputs held
    // ------------------------------------------------------------------
    @(negedge clk);
    clear_all();
    set_die0(32'hA5A5_0001, 2'b01, 1'b1);  // die0 → die1(r0,c1)

    @(posedge clk); #1;
    chk("TC2 1-hop die0->die1 vld_out[1]",  vld_out[1] == 1'b1);
    chk("TC2 1-hop die0->die1 flit_out[1]", gfo1() == 32'hA5A5_0001);
    chk("TC2 no spurious vld_out[0]",        vld_out[0] == 1'b0);
    chk("TC2 no spurious vld_out[2]",        vld_out[2] == 1'b0);
    chk("TC2 no spurious vld_out[3]",        vld_out[3] == 1'b0);

    // ------------------------------------------------------------------
    // TC1: die0 → die3 (2-hop, opposite corner)
    //   Hop1: (0,0)→(0,1)=die1 at posedge N+1
    //   Hop2: die1-reg auto-forwards (0,1)→(1,1)=die3 at posedge N+2
    //   Inject die0 at negedge N; clear injection at negedge N+1;
    //   sample die3 at posedge N+2.
    // ------------------------------------------------------------------
    @(negedge clk);
    clear_all();
    set_die0(32'hDEAD_BEEF, 2'b11, 1'b1);  // die0 → die3(r1,c1)

    @(posedge clk); #1;          // hop1: die1 reg loaded
    @(negedge clk); clear_all(); // remove die0 injection

    @(posedge clk); #1;          // hop2: die3 delivered
    chk("TC1 2-hop die0->die3 vld_out[3]",  vld_out[3] == 1'b1);
    chk("TC1 2-hop die0->die3 flit_out[3]", gfo3() == 32'hDEAD_BEEF);
    chk("TC1 no spurious vld_out[0]",        vld_out[0] == 1'b0);
    chk("TC1 no spurious vld_out[1]",        vld_out[1] == 1'b0);
    chk("TC1 no spurious vld_out[2]",        vld_out[2] == 1'b0);

    // ------------------------------------------------------------------
    // TC3: 4 simultaneous 1-hop broadcasts (zero contention)
    //   die0(0,0)→die1(0,1): next=die1 (E)
    //   die1(0,1)→die3(1,1): next=die3 (S)
    //   die2(1,0)→die0(0,0): next=die0 (N)
    //   die3(1,1)→die2(1,0): next=die2 (W)
    //   All 4 targets distinct → zero contention → deliver in 1 hop
    // ------------------------------------------------------------------
    @(negedge clk);
    clear_all();
    set_die0(32'hC0DE_0001, 2'b01, 1'b1);  // die0 → die1
    set_die1(32'hC0DE_0002, 2'b11, 1'b1);  // die1 → die3
    set_die2(32'hC0DE_0003, 2'b00, 1'b1);  // die2 → die0
    set_die3(32'hC0DE_0004, 2'b10, 1'b1);  // die3 → die2

    @(posedge clk); #1;
    chk("TC3 die0->die1 vld_out[1]",  vld_out[1] == 1'b1);
    chk("TC3 die0->die1 flit_out[1]", gfo1() == 32'hC0DE_0001);
    chk("TC3 die1->die3 vld_out[3]",  vld_out[3] == 1'b1);
    chk("TC3 die1->die3 flit_out[3]", gfo3() == 32'hC0DE_0002);
    chk("TC3 die2->die0 vld_out[0]",  vld_out[0] == 1'b1);
    chk("TC3 die2->die0 flit_out[0]", gfo0() == 32'hC0DE_0003);
    chk("TC3 die3->die2 vld_out[2]",  vld_out[2] == 1'b1);
    chk("TC3 die3->die2 flit_out[2]", gfo2() == 32'hC0DE_0004);

    // ------------------------------------------------------------------
    // Final verdict
    // ------------------------------------------------------------------
    $display("");
    if (fail_count == 0) begin
      $display("LANE V-PRIME 2x2 MESH NOC TEST PASS");
      $display("  Tests passed: %0d / %0d", pass_count, pass_count + fail_count);
    end else begin
      $display("LANE V-PRIME 2x2 MESH NOC TEST FAIL");
      $display("  Passed: %0d  Failed: %0d", pass_count, fail_count);
    end
    $finish;
  end

  initial begin #20000; $display("TIMEOUT"); $finish; end

endmodule
// =============================================================================
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
// Lane V' testbench — L-DPC25 Wave-28
// =============================================================================
