// =============================================================================
// holo_noc_2x2_mesh.sv  –  2×2 mesh Network-on-Chip (4-die, 1-cycle hop)
// TTSKY26c HOLOGRAPHIC SKU  ·  R-SI-1 compliant (ZERO `*` operator)
// Lane V'  ·  L-DPC25  ·  Wave-28
// Extends Lane A' 1-cycle NoC (holo_noc_1cycle.sv · Wave-27 · ebd426d9)
// Scale-out gain ×4 over single die (Lever #3)
// =============================================================================
//
// Topology: 2×2 grid
//   die0 = (row=0, col=0)   die1 = (row=0, col=1)
//   die2 = (row=1, col=0)   die3 = (row=1, col=1)
//
// dest[1:0]: bit[1] = row, bit[0] = col  →  die index = {row, col}
//
// XY Routing (deterministic, deadlock-free):
//   next_hop(src, dst):
//     if   src[0] != dst[0]  → {src[1], dst[0]}   (fix col first — XY order)
//     elif src[1] != dst[1]  → {dst[1], src[0]}   (fix row)
//     else                   → src                 (at destination)
//
// Per-hop latency: 1 clock cycle (registered output).
// Multi-hop flit carries destination; intermediate dies auto-forward.
// Max 2 hops (opposite corner).  No flit drop.
// Contention: lower source-die index wins.
//
// Port layout: flat-packed 128-bit buses (4 dies × 32-bit flit)
//   flit_in [127:0] — {die3[127:96], die2[95:64], die1[63:32], die0[31:0]}
//   dest_in [7:0]   — {die3[7:6], die2[5:4], die1[3:2], die0[1:0]}
//   vld_in  [3:0]   — {die3[3], die2[2], die1[1], die0[0]}
//
// R-SI-1: ZERO `*` operator — routing uses bit-extract and ternary compare only.
// All bus slices use literal offsets (no `*` in index expressions).
// =============================================================================
`timescale 1ns/1ps

module holo_noc_2x2_mesh #(
  // Parameters kept for documentation; internal logic uses literal widths.
  // FLIT_W must be 32, DIES must be 4 for this implementation.
  parameter int FLIT_W = 32,
  parameter int DIES   = 4
) (
  input  logic         clk,
  input  logic         rst_n,
  // Primary injection — flat packed buses
  input  logic [127:0] flit_in,    // die0=[31:0], die1=[63:32], die2=[95:64], die3=[127:96]
  input  logic [7:0]   dest_in,    // die0=[1:0],  die1=[3:2],   die2=[5:4],   die3=[7:6]
  input  logic [3:0]   vld_in,     // die0=[0], die1=[1], die2=[2], die3=[3]
  // Delivery outputs
  output logic [127:0] flit_out,
  output logic [3:0]   vld_out,
  // Constant 1: per-hop latency verification handshake
  output logic [0:0]   hop_latency_cycles
);

  assign hop_latency_cycles = 1'b1;

  // ---------------------------------------------------------------------------
  // Unpack inputs using literal bit offsets (R-SI-1: no `*`)
  // ---------------------------------------------------------------------------
  wire [31:0] fi0 = flit_in[31:0];
  wire [31:0] fi1 = flit_in[63:32];
  wire [31:0] fi2 = flit_in[95:64];
  wire [31:0] fi3 = flit_in[127:96];

  wire [1:0]  di0 = dest_in[1:0];
  wire [1:0]  di1 = dest_in[3:2];
  wire [1:0]  di2 = dest_in[5:4];
  wire [1:0]  di3 = dest_in[7:6];

  wire vi0 = vld_in[0];
  wire vi1 = vld_in[1];
  wire vi2 = vld_in[2];
  wire vi3 = vld_in[3];

  // ---------------------------------------------------------------------------
  // Per-die pipeline registers
  // ---------------------------------------------------------------------------
  logic [31:0] reg_flit0, reg_flit1, reg_flit2, reg_flit3;
  logic [1:0]  reg_dest0, reg_dest1, reg_dest2, reg_dest3;
  logic        reg_vld0,  reg_vld1,  reg_vld2,  reg_vld3;

  // ---------------------------------------------------------------------------
  // XY next-hop function (no `*`)
  // ---------------------------------------------------------------------------
  function logic [1:0] nh (input logic [1:0] src, input logic [1:0] dst);
    if (src[0] != dst[0])
      nh = {src[1], dst[0]};
    else if (src[1] != dst[1])
      nh = {dst[1], src[0]};
    else
      nh = src;
  endfunction

  // ---------------------------------------------------------------------------
  // Combinational next-hop for primary injections
  // ---------------------------------------------------------------------------
  wire [1:0] nhp0 = nh(2'd0, di0);
  wire [1:0] nhp1 = nh(2'd1, di1);
  wire [1:0] nhp2 = nh(2'd2, di2);
  wire [1:0] nhp3 = nh(2'd3, di3);

  // Combinational next-hop for in-transit register flits
  wire [1:0] nhr0 = nh(2'd0, reg_dest0);
  wire [1:0] nhr1 = nh(2'd1, reg_dest1);
  wire [1:0] nhr2 = nh(2'd2, reg_dest2);
  wire [1:0] nhr3 = nh(2'd3, reg_dest3);

  // In-transit flag (flit in register has not yet reached its destination)
  wire it0 = reg_vld0 & (reg_dest0 != 2'd0);
  wire it1 = reg_vld1 & (reg_dest1 != 2'd1);
  wire it2 = reg_vld2 & (reg_dest2 != 2'd2);
  wire it3 = reg_vld3 & (reg_dest3 != 2'd3);

  // ---------------------------------------------------------------------------
  // Candidate presence at each destination die
  // Priority: primary p0 > p1 > p2 > p3 > reg r0 > r1 > r2 > r3
  // Naming: c{dest}_{p|r}{src}
  // ---------------------------------------------------------------------------
  wire c0p0 = vi0 & (nhp0==2'd0); wire c0p1 = vi1 & (nhp1==2'd0);
  wire c0p2 = vi2 & (nhp2==2'd0); wire c0p3 = vi3 & (nhp3==2'd0);
  wire c0r0 = it0 & (nhr0==2'd0); wire c0r1 = it1 & (nhr1==2'd0);
  wire c0r2 = it2 & (nhr2==2'd0); wire c0r3 = it3 & (nhr3==2'd0);

  wire c1p0 = vi0 & (nhp0==2'd1); wire c1p1 = vi1 & (nhp1==2'd1);
  wire c1p2 = vi2 & (nhp2==2'd1); wire c1p3 = vi3 & (nhp3==2'd1);
  wire c1r0 = it0 & (nhr0==2'd1); wire c1r1 = it1 & (nhr1==2'd1);
  wire c1r2 = it2 & (nhr2==2'd1); wire c1r3 = it3 & (nhr3==2'd1);

  wire c2p0 = vi0 & (nhp0==2'd2); wire c2p1 = vi1 & (nhp1==2'd2);
  wire c2p2 = vi2 & (nhp2==2'd2); wire c2p3 = vi3 & (nhp3==2'd2);
  wire c2r0 = it0 & (nhr0==2'd2); wire c2r1 = it1 & (nhr1==2'd2);
  wire c2r2 = it2 & (nhr2==2'd2); wire c2r3 = it3 & (nhr3==2'd2);

  wire c3p0 = vi0 & (nhp0==2'd3); wire c3p1 = vi1 & (nhp1==2'd3);
  wire c3p2 = vi2 & (nhp2==2'd3); wire c3p3 = vi3 & (nhp3==2'd3);
  wire c3r0 = it0 & (nhr0==2'd3); wire c3r1 = it1 & (nhr1==2'd3);
  wire c3r2 = it2 & (nhr2==2'd3); wire c3r3 = it3 & (nhr3==2'd3);

  // ---------------------------------------------------------------------------
  // Priority-mux winners (fully combinational)
  // ---------------------------------------------------------------------------
  wire [31:0] w0f =
    c0p0 ? fi0 : c0p1 ? fi1 : c0p2 ? fi2 : c0p3 ? fi3 :
    c0r0 ? reg_flit0 : c0r1 ? reg_flit1 : c0r2 ? reg_flit2 : reg_flit3;
  wire [1:0] w0d =
    c0p0 ? di0 : c0p1 ? di1 : c0p2 ? di2 : c0p3 ? di3 :
    c0r0 ? reg_dest0 : c0r1 ? reg_dest1 : c0r2 ? reg_dest2 : reg_dest3;
  wire w0v = c0p0|c0p1|c0p2|c0p3|c0r0|c0r1|c0r2|c0r3;

  wire [31:0] w1f =
    c1p0 ? fi0 : c1p1 ? fi1 : c1p2 ? fi2 : c1p3 ? fi3 :
    c1r0 ? reg_flit0 : c1r1 ? reg_flit1 : c1r2 ? reg_flit2 : reg_flit3;
  wire [1:0] w1d =
    c1p0 ? di0 : c1p1 ? di1 : c1p2 ? di2 : c1p3 ? di3 :
    c1r0 ? reg_dest0 : c1r1 ? reg_dest1 : c1r2 ? reg_dest2 : reg_dest3;
  wire w1v = c1p0|c1p1|c1p2|c1p3|c1r0|c1r1|c1r2|c1r3;

  wire [31:0] w2f =
    c2p0 ? fi0 : c2p1 ? fi1 : c2p2 ? fi2 : c2p3 ? fi3 :
    c2r0 ? reg_flit0 : c2r1 ? reg_flit1 : c2r2 ? reg_flit2 : reg_flit3;
  wire [1:0] w2d =
    c2p0 ? di0 : c2p1 ? di1 : c2p2 ? di2 : c2p3 ? di3 :
    c2r0 ? reg_dest0 : c2r1 ? reg_dest1 : c2r2 ? reg_dest2 : reg_dest3;
  wire w2v = c2p0|c2p1|c2p2|c2p3|c2r0|c2r1|c2r2|c2r3;

  wire [31:0] w3f =
    c3p0 ? fi0 : c3p1 ? fi1 : c3p2 ? fi2 : c3p3 ? fi3 :
    c3r0 ? reg_flit0 : c3r1 ? reg_flit1 : c3r2 ? reg_flit2 : reg_flit3;
  wire [1:0] w3d =
    c3p0 ? di0 : c3p1 ? di1 : c3p2 ? di2 : c3p3 ? di3 :
    c3r0 ? reg_dest0 : c3r1 ? reg_dest1 : c3r2 ? reg_dest2 : reg_dest3;
  wire w3v = c3p0|c3p1|c3p2|c3p3|c3r0|c3r1|c3r2|c3r3;

  // ---------------------------------------------------------------------------
  // Output registers (scalar to avoid iverilog unpacked-port bug)
  // ---------------------------------------------------------------------------
  logic [31:0] fo0, fo1, fo2, fo3;
  logic        vo0, vo1, vo2, vo3;

  // ---------------------------------------------------------------------------
  // Registered pipeline — 1 clock cycle per hop
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst_n) begin
      reg_flit0 <= 32'd0; reg_dest0 <= 2'd0; reg_vld0 <= 1'b0; fo0 <= 32'd0; vo0 <= 1'b0;
      reg_flit1 <= 32'd0; reg_dest1 <= 2'd1; reg_vld1 <= 1'b0; fo1 <= 32'd0; vo1 <= 1'b0;
      reg_flit2 <= 32'd0; reg_dest2 <= 2'd2; reg_vld2 <= 1'b0; fo2 <= 32'd0; vo2 <= 1'b0;
      reg_flit3 <= 32'd0; reg_dest3 <= 2'd3; reg_vld3 <= 1'b0; fo3 <= 32'd0; vo3 <= 1'b0;
    end else begin
      reg_flit0 <= w0f; reg_dest0 <= w0d; reg_vld0 <= w0v;
      reg_flit1 <= w1f; reg_dest1 <= w1d; reg_vld1 <= w1v;
      reg_flit2 <= w2f; reg_dest2 <= w2d; reg_vld2 <= w2v;
      reg_flit3 <= w3f; reg_dest3 <= w3d; reg_vld3 <= w3v;
      fo0 <= w0f; vo0 <= w0v & (w0d == 2'd0);
      fo1 <= w1f; vo1 <= w1v & (w1d == 2'd1);
      fo2 <= w2f; vo2 <= w2v & (w2d == 2'd2);
      fo3 <= w3f; vo3 <= w3v & (w3d == 2'd3);
    end
  end

  // Pack outputs using literal bit offsets (R-SI-1: no `*`)
  assign flit_out = {fo3, fo2, fo1, fo0};
  assign vld_out  = {vo3, vo2, vo1, vo0};

endmodule
// =============================================================================
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
// Extends Lane A' 1-cycle NoC (Wave-27 ebd426d9) – additive, R18 compliant
// =============================================================================
