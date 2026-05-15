// =============================================================================
// holo_noc_1cycle_tb.sv  –  Testbench for holo_noc_1cycle
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant
// Lane A'  ·  L-DPC24 HOLOGRAPHIC v9  ·  holo-noc-1cycle
// =============================================================================
`timescale 1ns/1ps

module holo_noc_1cycle_tb;

  // Parameters
  localparam int FLIT_W = 32;
  localparam int DIES   = 2;

  // DUT signals
  logic                       clk;
  logic                       rst_n;
  logic [FLIT_W-1:0]          flit_in [DIES];
  logic                       vld_in  [DIES];
  logic [FLIT_W-1:0]          flit_out[DIES];
  logic                       vld_out [DIES];
  logic [$clog2(DIES+1)-1:0]  latency_cycles;

  // Instantiate DUT
  holo_noc_1cycle #(
    .FLIT_W(FLIT_W),
    .DIES  (DIES)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .flit_in       (flit_in),
    .vld_in        (vld_in),
    .flit_out      (flit_out),
    .vld_out       (vld_out),
    .latency_cycles(latency_cycles)
  );

  // Clock generation: 10 ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Flit stimulus data (8 flits per die, no multiplier operators used)
  logic [FLIT_W-1:0] stim_die0 [8];
  logic [FLIT_W-1:0] stim_die1 [8];

  // Expected outputs captured one cycle after input
  logic [FLIT_W-1:0] exp_die0 [8];
  logic [FLIT_W-1:0] exp_die1 [8];

  integer i;
  integer errors;

  initial begin
    errors = 0;

    // Initialise stimulus (using + and | only, no *)
    stim_die0[0] = 32'hA0000001;
    stim_die0[1] = 32'hA0000002;
    stim_die0[2] = 32'hA0000004;
    stim_die0[3] = 32'hA0000008;
    stim_die0[4] = 32'hA0000010;
    stim_die0[5] = 32'hA0000020;
    stim_die0[6] = 32'hA0000040;
    stim_die0[7] = 32'hA0000080;

    stim_die1[0] = 32'hB0000001;
    stim_die1[1] = 32'hB0000002;
    stim_die1[2] = 32'hB0000004;
    stim_die1[3] = 32'hB0000008;
    stim_die1[4] = 32'hB0000010;
    stim_die1[5] = 32'hB0000020;
    stim_die1[6] = 32'hB0000040;
    stim_die1[7] = 32'hB0000080;

    // After swap: die0 output = die1 input; die1 output = die0 input
    for (i = 0; i < 8; i++) begin
      exp_die0[i] = stim_die1[i];
      exp_die1[i] = stim_die0[i];
    end

    // Reset for 2 cycles
    rst_n = 0;
    flit_in[0] = '0;
    flit_in[1] = '0;
    vld_in[0]  = 0;
    vld_in[1]  = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    rst_n = 1;

    // Assert latency_cycles == 1
    if (latency_cycles !== 1) begin
      $display("ERROR: latency_cycles = %0d, expected 1", latency_cycles);
      errors = errors + 1;
    end
    $display("R5-HONEST: NoC latency = %0d cycle(s)", latency_cycles);

    // Drive 8 flits and check output one cycle later
    for (i = 0; i < 8; i++) begin
      // Apply inputs at this cycle
      flit_in[0] = stim_die0[i];
      flit_in[1] = stim_die1[i];
      vld_in[0]  = 1;
      vld_in[1]  = 1;
      @(posedge clk); #1;
      // Sample outputs after rising edge (1 cycle latency)
      if (i > 0) begin
        // Check previous cycle's expected output
        if (flit_out[0] !== exp_die0[i-1]) begin
          $display("ERROR cycle %0d: flit_out[0]=0x%08h, expected 0x%08h",
                   i, flit_out[0], exp_die0[i-1]);
          errors = errors + 1;
        end
        if (flit_out[1] !== exp_die1[i-1]) begin
          $display("ERROR cycle %0d: flit_out[1]=0x%08h, expected 0x%08h",
                   i, flit_out[1], exp_die1[i-1]);
          errors = errors + 1;
        end
        if (!vld_out[0] || !vld_out[1]) begin
          $display("ERROR cycle %0d: vld_out[0]=%0b vld_out[1]=%0b, expected both 1",
                   i, vld_out[0], vld_out[1]);
          errors = errors + 1;
        end
      end
    end

    // Check last flit output
    if (flit_out[0] !== exp_die0[7]) begin
      $display("ERROR last: flit_out[0]=0x%08h, expected 0x%08h",
               flit_out[0], exp_die0[7]);
      errors = errors + 1;
    end
    if (flit_out[1] !== exp_die1[7]) begin
      $display("ERROR last: flit_out[1]=0x%08h, expected 0x%08h",
               flit_out[1], exp_die1[7]);
      errors = errors + 1;
    end

    // Drain: idle for remaining cycles up to 16 total
    vld_in[0] = 0;
    vld_in[1] = 0;
    repeat (6) @(posedge clk);

    if (errors == 0)
      $display("PASS: All NoC checks passed. latency=1 cycle, R-SI-1 compliant.");
    else
      $display("FAIL: %0d error(s) detected.", errors);

    $finish;
  end

endmodule
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
