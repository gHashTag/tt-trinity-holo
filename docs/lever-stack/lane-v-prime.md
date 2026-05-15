# Lane V' — 2×2 Holo-Mesh NoC Spec

**Lane:** V' (L-DPC25)  
**Status:** Feature branch `feat/l-dpc25/v-prime-mesh-2x2`  
**Author:** Vasilev Dmitrii `<admin@t27.ai>`  
**Base:** Lane A' `holo_noc_1cycle` merged at `78362042` on tt-trinity-holo#13  
**ONE SHOT parent:** [trinity-fpga#104](https://github.com/gHashTag/trinity-fpga/issues/104) — Lever Stack  
**Штаб canonical:** [trios#834](https://github.com/gHashTag/trios/issues/834)  
**Algebraic anchor:** φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## 1. Contract

| Property | Value |
|---|---|
| Topology | 2×2 mesh (4 nodes) |
| Routing algorithm | XY dimension-ordered (X first, then Y) |
| Max hop count | 2 (corner-to-corner, diameter of 2×2 mesh) |
| Hop latency | 1 register cycle per hop |
| Max end-to-end latency | 2 cycles (2-hop path) |
| Deadlock guarantee | Provably deadlock-free (Dally & Seitz 1987 — XY routing eliminates cyclic channel dependencies) |
| Livelock guarantee | Minimal path (Manhattan) — no livelock possible |
| Throughput model | 4 dies × 1 op/cycle = 4 ops/cycle peak (4× Lane A' single-die) |
| R-SI-1 compliance | Zero `*` operators in all RTL files |
| R18 compliance | `holo_noc_1cycle.sv` is unmodified; this lane is additive only |

---

## 2. Topology

```
X →
Y     x=0        x=1
↓
y=0   N0(0,0) ——E/W—— N1(1,0)
       |                |
      N/S              N/S
       |                |
y=1   N2(0,1) ——E/W—— N3(1,1)
```

Node ID encoding: `node_id = x | (y << 1)`

| node_id | Name | (x, y) |
|---|---|---|
| 0 | N0 | (0, 0) |
| 1 | N1 | (1, 0) |
| 2 | N2 | (0, 1) |
| 3 | N3 | (1, 1) |

**Links:**
- N0↔N1: East/West, row y=0
- N2↔N3: East/West, row y=1
- N0↔N2: North/South, column x=0
- N1↔N3: North/South, column x=1

---

## 3. Module Hierarchy

```
holo_mesh_2x2
├── u_noc0 : holo_noc_1cycle  (Lane A', unmodified, die 0)
├── u_router0 : holo_mesh_router  (XY router, CUR_X=0, CUR_Y=0)
├── u_noc1 : holo_noc_1cycle  (die 1)
├── u_router1 : holo_mesh_router  (CUR_X=1, CUR_Y=0)
├── u_noc2 : holo_noc_1cycle  (die 2)
├── u_router2 : holo_mesh_router  (CUR_X=0, CUR_Y=1)
├── u_noc3 : holo_noc_1cycle  (die 3)
└── u_router3 : holo_mesh_router  (CUR_X=1, CUR_Y=1)
```

---

## 4. Port Specification

### `holo_mesh_2x2` (top module)

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock (posedge) |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `inj_flit[4]` | input | FLIT_W | Flit to inject at each node |
| `inj_vld[4]` | input | 1 | Inject valid per node |
| `ej_flit[4]` | output | FLIT_W | Delivered flit at each node |
| `ej_vld[4]` | output | 1 | Eject valid per node |
| `noc_latency[4]` | output | 1 | Lane A' latency observable (always 1) |

**Flit address encoding:**  
`flit[3:2]` = dst_x (0 or 1)  
`flit[1:0]` = dst_y (0 or 1)  
`flit[FLIT_W-1:4]` = payload

### `holo_mesh_router` (per-node cell)

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock |
| `rst_n` | input | 1 | Reset |
| `flit_in[5]` | input | FLIT_W | Flits from N/S/E/W/Local ports |
| `vld_in[5]` | input | 1 | Valid per input port |
| `flit_out[5]` | output | FLIT_W | Flits to N/S/E/W/Local ports |
| `vld_out[5]` | output | 1 | Valid per output port |

Port index: `PORT_N=0, PORT_S=1, PORT_E=2, PORT_W=3, PORT_L=4`

Parameters: `FLIT_W` (default 32), `CUR_X` (0 or 1), `CUR_Y` (0 or 1)

---

## 5. XY Routing Algorithm

For an input flit arriving at router `(CUR_X, CUR_Y)` with destination `(dst_x, dst_y)`:

```
if dst_x > CUR_X  → forward EAST  (PORT_E)
if dst_x < CUR_X  → forward WEST  (PORT_W)
else if dst_y > CUR_Y → forward SOUTH (PORT_S)
else if dst_y < CUR_Y → forward NORTH (PORT_N)
else              → deliver LOCAL  (PORT_L)
```

This dimension-ordered routing guarantees:
1. **No deadlock**: X routes are fully resolved before Y routes, breaking all cyclic channel dependency chains.
2. **Minimal path**: Each flit traverses exactly `|Δx| + |Δy|` hops (Manhattan distance).
3. **1-cycle hop**: One pipeline register per router stage.

---

## 6. Throughput Model

| Metric | Value | Derivation |
|---|---|---|
| Single-die peak (Lane A') | 1 op/cycle | `holo_noc_1cycle` throughput |
| 4-die mesh peak | 4 ops/cycle | 4 nodes × 1 op/cycle (independent local inject) |
| Scale factor | 4× | 4 ops vs 1 op |
| Bisection bandwidth | 2 flits/cycle | 2 cross-links (N0↔N1, N0↔N2 or N2↔N3, N1↔N3) |
| Worst-case latency (2-hop) | 2 cycles | 2 register stages |
| Latency overhead vs Lane A' | +1 cycle (max) | Lane A' = 1 cy; 2-hop = 2 cy |

**Predicted gain:** 4× throughput at ≤ 2× latency overhead for cross-die traffic. Local-die traffic maintains Lane A' 1-cycle latency with zero overhead.

---

## 7. Pairwise Hop Matrix

| src\dst | N0 | N1 | N2 | N3 |
|---|---|---|---|---|
| N0 | 0 | 1 | 1 | 2 |
| N1 | 1 | 0 | 2 | 1 |
| N2 | 1 | 2 | 0 | 1 |
| N3 | 2 | 1 | 1 | 0 |

Max = 2 (corner to corner). Coq lemma: `mesh_1cycle ≡ ∀ src dst, hops(src,dst) ≤ 2`.

---

## 8. Pre-Registration (G2)

| Field | Value |
|---|---|
| `statistical_test` | Structural assertion — mesh is k-cycle hop iff Coq lemma `mesh_1cycle ≡ ∀ src dst, hops(src,dst) ≤ 2` |
| `effect_size` | 4× throughput vs single-die Lane A' (4 dies × 1 op/cycle = 4 ops/cycle peak) |
| `falsification_predicate` | Refuted iff (a) any RTL `*`, OR (b) any 2-cycle single-hop, OR (c) deadlock under uniform-random traffic, OR (d) latency > Lane A' + 1 cycle |
| `n_required` | 1000 random traffic patterns in `tb/tb_holo_mesh_2x2.sv` |
| `stop_rule` | First commit where all 3 Rust falsification witnesses pass + R-SI-1 CI green |
| `multiple_testing` | n/a — three orthogonal structural predicates |

---

## 9. Falsification Witnesses (R7)

Three `#[test]` functions in `falsif/v_prime_witness.rs`:

| Test | Predicate | Falsified iff |
|---|---|---|
| `test_mesh_no_star` | P4a `mesh_2x2_no_star` | `*` operator in RTL |
| `test_mesh_1cycle_hop` | P4b `mesh_1cycle_hop` | any path > 2 hops or > 2-cycle latency |
| `test_mesh_deadlock_free` | P4c `mesh_deadlock_free` | any cycle in XY routing path |

---

## 10. Quantum Brain 1:1 Silicon Mapping

This lane extends the **LANG→SI** path:

- Opcodes `OP_BITROM_READ 0xE0` (Lane W storage) provide operands via the 4-die mesh.
- `OP_MESH_HOP` (not a new Sacred ROM opcode — range 0xD0..0xE0 is R18-frozen) is the interconnect primitive that routes flits between the 4 dies running the 3-opcode QB ISA.
- Each die independently executes `OP_NOP/0x00`, `OP_HOLO/0xFF`, `OP_BITROM_READ/0xE0`; the mesh fabric aggregates their outputs.

---

## 11. Reference Anchors

| Anchor | Ref |
|---|---|
| Lane A' base | tt-trinity-holo#13 at `78362042` |
| Lane W BitROM | tt-trinity-holo#14 (storage layer) |
| Lane V Platinum LUT PE | tt-trinity-max-true#13 (in flight) |
| Lane X 6-op alphabet | t27#637 at `5758b53c` |
| Algebraic: φ²+φ⁻²=3 | [DOI 10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |
| ASP-DAC 2026 NoC scale-out | arXiv 2511.21910 |
| ONE SHOT parent | [trinity-fpga#104](https://github.com/gHashTag/trinity-fpga/issues/104) |

---

*φ² + φ⁻² = 3 · 4× mesh scale-out · 2×2 holo · NEVER STOP · LANG→SI*
