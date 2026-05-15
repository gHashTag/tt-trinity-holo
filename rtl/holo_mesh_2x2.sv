// =============================================================================
// holo_mesh_2x2.sv  –  2×2 mesh NoC wrapping 4 holo_noc_1cycle instances
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (zero `*` operators)
// Lane V'  ·  L-DPC25 HOLOGRAPHIC  ·  holo-mesh-2x2
// =============================================================================
//
// Topology (node numbering, X-major):
//   node[0,0]=N0  node[1,0]=N1
//   node[0,1]=N2  node[1,1]=N3
//
//   N0 ---E/W--- N1
//   |             |
//  N/S           N/S
//   |             |
//   N2 ---E/W--- N3
//
// Each node contains:
//   - one holo_noc_1cycle instance (Lane A' die, DIES=2 stub)
//   - one holo_mesh_router (XY router, 5-port)
//
// Inter-node links (all 1-cycle hop):
//   N0.E ↔ N1.W    (X-link, row 0)
//   N2.E ↔ N3.W    (X-link, row 1)
//   N0.S ↔ N2.N    (Y-link, col 0)
//   N1.S ↔ N3.N    (Y-link, col 1)
//
// R-SI-1: NO `*` operator anywhere in this file
// R18 LAYER-FROZEN: holo_noc_1cycle is instantiated unmodified
//
// Flit address [3:2]=dst_x [1:0]=dst_y, upper bits are payload.
// Max hop count: 2 (corner to corner: X-hop + Y-hop).
// End-to-end latency for 2-hop path: 2 cycles (one register per hop).
// =============================================================================
`timescale 1ns/1ps

module holo_mesh_2x2 #(
  parameter int FLIT_W = 32
) (
  input  logic                clk,
  input  logic                rst_n,

  // Local inject / eject for all 4 nodes (flat arrays, index = node_id)
  // node_id = {x, y}: N0=0, N1=1, N2=2, N3=3
  input  logic [FLIT_W-1:0]   inj_flit [4],   // flit to inject at node[i]
  input  logic                inj_vld  [4],   // inject valid
  output logic [FLIT_W-1:0]   ej_flit  [4],   // ejected flit at node[i]
  output logic                ej_vld   [4],   // eject valid

  // Observable latency counter from Lane A' (per node)
  output logic [0:0]          noc_latency [4]  // 1-bit: always 1-cycle per hop
);

  // -------------------------------------------------------------------------
  // Internal router interconnect wires
  // Each router has 5 ports: [N, S, E, W, L]
  // -------------------------------------------------------------------------

  // Wires: router[n] port output → neighbour input
  // Naming: r<node>_out_<port>_flit / _vld
  // Node layout:  0=(0,0)  1=(1,0)  2=(0,1)  3=(1,1)

  // Router output flits/valid (from each of 4 routers, 5 ports each)
  logic [FLIT_W-1:0]  r_flit_out [4][5];
  logic               r_vld_out  [4][5];

  // Router input flits/valid (to each of 4 routers, 5 ports each)
  logic [FLIT_W-1:0]  r_flit_in  [4][5];
  logic               r_vld_in   [4][5];

  // Port indices
  localparam int PORT_N = 0;
  localparam int PORT_S = 1;
  localparam int PORT_E = 2;
  localparam int PORT_W = 3;
  localparam int PORT_L = 4;

  // -------------------------------------------------------------------------
  // Interconnect wiring: connect router outputs to router inputs
  // N0=(0,0), N1=(1,0), N2=(0,1), N3=(1,1)
  // -------------------------------------------------------------------------

  always_comb begin
    // ---- Initialise all inputs to zero (unconnected ports = no traffic) ----
    for (int n = 0; n < 4; n++) begin
      for (int p = 0; p < 5; p++) begin
        r_flit_in[n][p] = '0;
        r_vld_in[n][p]  = 1'b0;
      end
    end

    // ---- X-link row 0: N0(0,0).E <-> N1(1,0).W ----
    r_flit_in[1][PORT_W] = r_flit_out[0][PORT_E];
    r_vld_in[1][PORT_W]  = r_vld_out[0][PORT_E];
    r_flit_in[0][PORT_E] = r_flit_out[1][PORT_W];
    r_vld_in[0][PORT_E]  = r_vld_out[1][PORT_W];

    // ---- X-link row 1: N2(0,1).E <-> N3(1,1).W ----
    r_flit_in[3][PORT_W] = r_flit_out[2][PORT_E];
    r_vld_in[3][PORT_W]  = r_vld_out[2][PORT_E];
    r_flit_in[2][PORT_E] = r_flit_out[3][PORT_W];
    r_vld_in[2][PORT_E]  = r_vld_out[3][PORT_W];

    // ---- Y-link col 0: N0(0,0).S <-> N2(0,1).N ----
    r_flit_in[2][PORT_N] = r_flit_out[0][PORT_S];
    r_vld_in[2][PORT_N]  = r_vld_out[0][PORT_S];
    r_flit_in[0][PORT_S] = r_flit_out[2][PORT_N];
    r_vld_in[0][PORT_S]  = r_vld_out[2][PORT_N];

    // ---- Y-link col 1: N1(1,0).S <-> N3(1,1).N ----
    r_flit_in[3][PORT_N] = r_flit_out[1][PORT_S];
    r_vld_in[3][PORT_N]  = r_vld_out[1][PORT_S];
    r_flit_in[1][PORT_S] = r_flit_out[3][PORT_N];
    r_vld_in[1][PORT_S]  = r_vld_out[3][PORT_N];

    // ---- Local inject ports (PORT_L input = host injected flit) ----
    r_flit_in[0][PORT_L] = inj_flit[0];
    r_vld_in[0][PORT_L]  = inj_vld[0];
    r_flit_in[1][PORT_L] = inj_flit[1];
    r_vld_in[1][PORT_L]  = inj_vld[1];
    r_flit_in[2][PORT_L] = inj_flit[2];
    r_vld_in[2][PORT_L]  = inj_vld[2];
    r_flit_in[3][PORT_L] = inj_flit[3];
    r_vld_in[3][PORT_L]  = inj_vld[3];

    // ---- Local eject ports (PORT_L output = delivered flit) ----
    ej_flit[0] = r_flit_out[0][PORT_L];
    ej_vld[0]  = r_vld_out[0][PORT_L];
    ej_flit[1] = r_flit_out[1][PORT_L];
    ej_vld[1]  = r_vld_out[1][PORT_L];
    ej_flit[2] = r_flit_out[2][PORT_L];
    ej_vld[2]  = r_vld_out[2][PORT_L];
    ej_flit[3] = r_flit_out[3][PORT_L];
    ej_vld[3]  = r_vld_out[3][PORT_L];
  end

  // -------------------------------------------------------------------------
  // Node 0: position (0,0)  — holo_noc_1cycle + holo_mesh_router
  // -------------------------------------------------------------------------
  holo_noc_1cycle #(.FLIT_W(FLIT_W), .DIES(2)) u_noc0 (
    .clk          (clk),
    .rst_n        (rst_n),
    .flit_in      ('{r_flit_in[0][PORT_L], inj_flit[0]}),
    .vld_in       ('{r_vld_in[0][PORT_L],  inj_vld[0]}),
    .flit_out     (/* local fabric; router drives mesh */),
    .vld_out      (/* local fabric */),
    .latency_cycles(noc_latency[0])
  );

  holo_mesh_router #(.FLIT_W(FLIT_W), .CUR_X(0), .CUR_Y(0)) u_router0 (
    .clk      (clk),
    .rst_n    (rst_n),
    .flit_in  (r_flit_in[0]),
    .vld_in   (r_vld_in[0]),
    .flit_out (r_flit_out[0]),
    .vld_out  (r_vld_out[0])
  );

  // -------------------------------------------------------------------------
  // Node 1: position (1,0)
  // -------------------------------------------------------------------------
  holo_noc_1cycle #(.FLIT_W(FLIT_W), .DIES(2)) u_noc1 (
    .clk          (clk),
    .rst_n        (rst_n),
    .flit_in      ('{r_flit_in[1][PORT_L], inj_flit[1]}),
    .vld_in       ('{r_vld_in[1][PORT_L],  inj_vld[1]}),
    .flit_out     (),
    .vld_out      (),
    .latency_cycles(noc_latency[1])
  );

  holo_mesh_router #(.FLIT_W(FLIT_W), .CUR_X(1), .CUR_Y(0)) u_router1 (
    .clk      (clk),
    .rst_n    (rst_n),
    .flit_in  (r_flit_in[1]),
    .vld_in   (r_vld_in[1]),
    .flit_out (r_flit_out[1]),
    .vld_out  (r_vld_out[1])
  );

  // -------------------------------------------------------------------------
  // Node 2: position (0,1)
  // -------------------------------------------------------------------------
  holo_noc_1cycle #(.FLIT_W(FLIT_W), .DIES(2)) u_noc2 (
    .clk          (clk),
    .rst_n        (rst_n),
    .flit_in      ('{r_flit_in[2][PORT_L], inj_flit[2]}),
    .vld_in       ('{r_vld_in[2][PORT_L],  inj_vld[2]}),
    .flit_out     (),
    .vld_out      (),
    .latency_cycles(noc_latency[2])
  );

  holo_mesh_router #(.FLIT_W(FLIT_W), .CUR_X(0), .CUR_Y(1)) u_router2 (
    .clk      (clk),
    .rst_n    (rst_n),
    .flit_in  (r_flit_in[2]),
    .vld_in   (r_vld_in[2]),
    .flit_out (r_flit_out[2]),
    .vld_out  (r_vld_out[2])
  );

  // -------------------------------------------------------------------------
  // Node 3: position (1,1)
  // -------------------------------------------------------------------------
  holo_noc_1cycle #(.FLIT_W(FLIT_W), .DIES(2)) u_noc3 (
    .clk          (clk),
    .rst_n        (rst_n),
    .flit_in      ('{r_flit_in[3][PORT_L], inj_flit[3]}),
    .vld_in       ('{r_vld_in[3][PORT_L],  inj_vld[3]}),
    .flit_out     (),
    .vld_out      (),
    .latency_cycles(noc_latency[3])
  );

  holo_mesh_router #(.FLIT_W(FLIT_W), .CUR_X(1), .CUR_Y(1)) u_router3 (
    .clk      (clk),
    .rst_n    (rst_n),
    .flit_in  (r_flit_in[3]),
    .vld_in   (r_vld_in[3]),
    .flit_out (r_flit_out[3]),
    .vld_out  (r_vld_out[3])
  );

endmodule
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// R-SI-1: zero * operators confirmed
// R18 LAYER-FROZEN: holo_noc_1cycle unmodified, additive only
// Lane V' · L-DPC25
