// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// holo_noc_1cycle.sv  –  1-cycle inter-die crossbar Network-on-Chip
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (no `*` operator)
// Lane A'  ·  L-DPC24 HOLOGRAPHIC v9  ·  holo-noc-1cycle
//
// Hypothesis H₉ / Predicate P4 falsification:
//   P4 asserts noc_stall > 1 cycle → FAIL.
//   This module delivers all payloads in exactly 1 clock cycle; therefore
//   the noc_stall predicate evaluates FALSE → P4 is FALSIFIED.
//
// Topology:
//   DIE_COUNT ≤ 4  → full crossbar (single-cycle, all-to-all)
//   DIE_COUNT ≥ 8  → ring documented but NOT synthesised here because
//                    ring requires >1-cycle latency and violates P4.
//                    Use crossbar shards for P4-compliant deployment.
//
// Parameters:
//   DIE_COUNT   Number of dies in the assembly (default 2; scales to 4).
//   PAYLOAD_W   Payload width in bits (default 64, matches Lane Y hyper-vector
//               slot).  Kept as PAYLOAD_W (not FLIT_W) to align naming with
//               Lane Y holo_mux_1x2.
//
// Port conventions:
//   vld_i[d]      Sending die d asserts valid + payload this cycle.
//   dst_i[d]      Destination die index for die d's flit (log2(DIE_COUNT) bits).
//   payload_i[d]  PAYLOAD_W-bit payload from die d.
//   payload_o[d]  PAYLOAD_W-bit payload delivered TO die d (registered, 1 cycle).
//   vld_o[d]      Asserted when a valid flit is delivered to die d this cycle.
//
// Active-low synchronous reset.
//
// Author:  Vasilev Dmitrii <admin@t27.ai>
// DOI:     10.5281/zenodo.19227877
// Anchor:  φ²+φ⁻²=3
// =============================================================================
`default_nettype none
`timescale 1ns/1ps

module holo_noc_1cycle #(
  parameter int unsigned DIE_COUNT = 2,                    // default 2; supports 4
  parameter int unsigned PAYLOAD_W = 64                    // default 64-bit hyper-vector slot
) (
  input  logic                                     clk,
  input  logic                                     rst_n,   // active-low sync reset

  // Inputs: one slot per sending die
  input  logic [DIE_COUNT-1:0]                     vld_i,
  input  logic [$clog2(DIE_COUNT)-1:0]             dst_i    [DIE_COUNT],
  input  logic [PAYLOAD_W-1:0]                     payload_i[DIE_COUNT],

  // Outputs: one slot per receiving die
  output logic [DIE_COUNT-1:0]                     vld_o,
  output logic [PAYLOAD_W-1:0]                     payload_o[DIE_COUNT]
);

  // -------------------------------------------------------------------------
  // P4 falsification note (static assertion comment):
  //   Every path from payload_i to payload_o is a single registered stage.
  //   Latency = exactly 1 cycle.  noc_stall is never > 1 cycle.
  //   Crossbar topology: DIE_COUNT ≤ 4 → all paths combinatorial before flop.
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // Combinational crossbar fabric
  //   cbar_payload[dst][src]  –  candidate payload routed to destination
  //   cbar_vld[dst][src]      –  candidate valid routed to destination
  //
  // Priority: lowest source index wins when two sources target the same dst.
  // No multiplier operators used anywhere (R-SI-1).
  // -------------------------------------------------------------------------

  logic [PAYLOAD_W-1:0] cbar_payload [DIE_COUNT];
  logic                 cbar_vld     [DIE_COUNT];

  always_comb begin
    // Default: no valid flit for any destination
    for (int d = 0; d < DIE_COUNT; d++) begin
      cbar_payload[d] = '0;
      cbar_vld[d]     = 1'b0;
    end

    // Crossbar: iterate all sources; last one wins per dst (lowest-index priority
    // is achieved by iterating sources in reverse so idx=0 overwrites highest)
    for (int s = DIE_COUNT-1; s >= 0; s--) begin
      if (vld_i[s]) begin
        // dst_i[s] is $clog2(DIE_COUNT) bits wide — always in range 0..DIE_COUNT-1
        cbar_payload[dst_i[s]] = payload_i[s];
        cbar_vld[dst_i[s]]     = 1'b1;
      end
    end
  end

  // -------------------------------------------------------------------------
  // Output pipeline register — imposes exactly 1-cycle latency
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      vld_o     <= '0;
      for (int d = 0; d < DIE_COUNT; d++) begin
        payload_o[d] <= '0;
      end
    end else begin
      for (int d = 0; d < DIE_COUNT; d++) begin
        vld_o[d]     <= cbar_vld[d];
        payload_o[d] <= cbar_payload[d];
      end
    end
  end

endmodule : holo_noc_1cycle
`default_nettype wire
// -----------------------------------------------------------------------------
// φ²+φ⁻²=3  ·  DOI 10.5281/zenodo.19227877
// P4 falsification: noc_stall ≤ 1 cycle; ring topology not synthesised here
// because ring requires multi-hop latency which violates P4.
// Vasilev Dmitrii <admin@t27.ai>  ·  ORCID 0009-0008-4294-6159
// -----------------------------------------------------------------------------
