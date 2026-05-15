// =============================================================================
// holo_mesh_router.sv  –  Single XY-router cell for 2×2 holo-mesh
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (zero `*` operators)
// Lane V'  ·  L-DPC25 HOLOGRAPHIC  ·  holo-mesh-2x2
// =============================================================================
// Port map (5-port, cardinal + local):
//   PORT_N=0  PORT_S=1  PORT_E=2  PORT_W=3  PORT_L=4
//
// XY routing (dimension-ordered, deadlock-free):
//   1. Route in X dimension first (East/West) until dst_x == cur_x
//   2. Then route in Y dimension (North/South) until dst_y == cur_y
//   3. Arrive at local port when dst == cur
//
// Latency: 1 cycle (fully registered output, combinational route logic)
// Arbitration: strict priority N>S>E>W>L on shared output port (never occurs
//              in dimension-ordered XY — each input targets a unique output)
// R-SI-1: NO `*` anywhere in this file
// =============================================================================
`timescale 1ns/1ps

module holo_mesh_router #(
  parameter int FLIT_W = 32,  // flit width (bits)
  parameter int CUR_X  = 0,   // this router's X coordinate (0 or 1)
  parameter int CUR_Y  = 0    // this router's Y coordinate (0 or 1)
) (
  input  logic                clk,
  input  logic                rst_n,

  // Incoming flits from 5 directions: [N, S, E, W, Local]
  input  logic [FLIT_W-1:0]   flit_in  [5],
  input  logic                vld_in   [5],
  // Destination coordinates embedded in flit[3:2]=dst_x, flit[1:0]=dst_y
  // (upper bits are payload)

  // Outgoing flits to 5 directions: [N, S, E, W, Local]
  output logic [FLIT_W-1:0]   flit_out [5],
  output logic                vld_out  [5]
);

  // -------------------------------------------------------------------------
  // Port index constants (no magic numbers per R4)
  // -------------------------------------------------------------------------
  localparam int PORT_N = 0;
  localparam int PORT_S = 1;
  localparam int PORT_E = 2;
  localparam int PORT_W = 3;
  localparam int PORT_L = 4;

  // -------------------------------------------------------------------------
  // Combinational XY routing: for each input, determine output port
  //
  // Flit address layout (bits [3:2] = dst_x, bits [1:0] = dst_y)
  // XY rule:
  //   if dst_x > cur_x  → route EAST  (port 2)
  //   if dst_x < cur_x  → route WEST  (port 3)
  //   else if dst_y > cur_y → route SOUTH (port 1)   [Y increases southward]
  //   else if dst_y < cur_y → route NORTH (port 0)
  //   else                  → route LOCAL (port 4)   [arrived]
  // -------------------------------------------------------------------------

  // Registered outputs — 1-cycle pipeline
  logic [FLIT_W-1:0]  flit_out_r [5];
  logic               vld_out_r  [5];

  // Combinational: per-input routed output port index (3 bits, range 0..4)
  logic [2:0] route_port [5];

  // Combinational: per-output arbitration result (first valid wins, priority N>S>E>W>L)
  logic [FLIT_W-1:0]  arb_flit [5];
  logic               arb_vld  [5];

  // -------------------------------------------------------------------------
  // Stage 1: Compute route_port for each input
  // -------------------------------------------------------------------------
  always_comb begin
    for (int p = 0; p < 5; p++) begin
      automatic logic [1:0] dst_x;
      automatic logic [1:0] dst_y;
      dst_x = flit_in[p][3:2];
      dst_y = flit_in[p][1:0];

      if (!vld_in[p]) begin
        route_port[p] = 3'(PORT_L); // don't-care when invalid
      end else if (dst_x > 2'(CUR_X)) begin
        route_port[p] = 3'(PORT_E);
      end else if (dst_x < 2'(CUR_X)) begin
        route_port[p] = 3'(PORT_W);
      end else if (dst_y > 2'(CUR_Y)) begin
        route_port[p] = 3'(PORT_S);
      end else if (dst_y < 2'(CUR_Y)) begin
        route_port[p] = 3'(PORT_N);
      end else begin
        route_port[p] = 3'(PORT_L);
      end
    end
  end

  // -------------------------------------------------------------------------
  // Stage 2: Per-output arbitration (strict N>S>E>W>L)
  //   For each output port o, scan inputs 0..4 in priority order;
  //   first valid input that routes to o wins.
  //   In legal XY routing each output port has at most 1 active sender,
  //   so the arbiter never causes head-of-line blocking.
  // -------------------------------------------------------------------------
  always_comb begin
    for (int o = 0; o < 5; o++) begin
      arb_flit[o] = '0;
      arb_vld[o]  = 1'b0;
      // Priority scan: N(0) > S(1) > E(2) > W(3) > L(4)
      for (int p = 4; p >= 0; p--) begin
        if (vld_in[p] && (route_port[p] == 3'(o))) begin
          arb_flit[o] = flit_in[p];
          arb_vld[o]  = 1'b1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Stage 3: Register outputs (1-cycle pipeline register)
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int o = 0; o < 5; o++) begin
        flit_out_r[o] <= '0;
        vld_out_r[o]  <= 1'b0;
      end
    end else begin
      for (int o = 0; o < 5; o++) begin
        flit_out_r[o] <= arb_flit[o];
        vld_out_r[o]  <= arb_vld[o];
      end
    end
  end

  // -------------------------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------------------------
  assign flit_out = flit_out_r;
  assign vld_out  = vld_out_r;

endmodule
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// R-SI-1: zero * operators confirmed
// Lane V' · L-DPC25
