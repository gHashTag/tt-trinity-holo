// =============================================================================
// holo_noc_1cycle.sv  –  1-cycle inter-die Network-on-Chip stub
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (no `*` operator)
// Lane A'  ·  L-DPC24 HOLOGRAPHIC v9  ·  holo-noc-1cycle
// =============================================================================
`timescale 1ns/1ps

module holo_noc_1cycle #(
  parameter int FLIT_W = 32,
  parameter int DIES   = 2
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic [FLIT_W-1:0]          flit_in [DIES],
  input  logic                       vld_in  [DIES],
  output logic [FLIT_W-1:0]          flit_out[DIES],
  output logic                       vld_out [DIES],
  output logic [$clog2(DIES+1)-1:0]  latency_cycles
);

  // -------------------------------------------------------------------------
  // Latency constant: always 1 cycle (registered output, combinational route)
  // -------------------------------------------------------------------------
  assign latency_cycles = $clog2(DIES+1)'(1);

  // -------------------------------------------------------------------------
  // 1-cycle pipeline registers
  // Routing: die[i] -> die[(i+1) % DIES]  (swap pattern, no multipliers)
  // For DIES=2: die0->die1, die1->die0
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < DIES; i++) begin
        flit_out[i] <= '0;
        vld_out[i]  <= 1'b0;
      end
    end else begin
      for (int i = 0; i < DIES; i++) begin
        // Cross-die route: source die index = (DIES - 1 - i) for swap pattern
        // For 2 dies: i=0 receives from i=1; i=1 receives from i=0
        // Computed without multiplier: src = (DIES - 1 - i)
        flit_out[i] <= flit_in[DIES - 1 - i];
        vld_out[i]  <= vld_in[DIES - 1 - i];
      end
    end
  end

endmodule
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
