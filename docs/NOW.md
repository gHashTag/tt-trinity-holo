# NOW — tt-trinity-holo active work

**φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)**

---

## Lane V' — 2×2 Mesh NoC · L-DPC25 Wave-28 ✅

**Status:** Delivered
**Branch:** `feat/lane-v-prime-2x2-mesh-noc`
**Tracking issue:** [tt-trinity-holo#16](https://github.com/gHashTag/tt-trinity-holo/issues/16)

### What was built

- `rtl/holo_noc_2x2_mesh.sv` — 4-die 2×2 mesh NoC, XY routing, 1-cycle hop, R-SI-1 clean
- `rtl/holo_noc_2x2_mesh_tb.sv` — 19 test assertions, all PASS
- `docs/L_DPC25_LANE_V_PRIME_2X2_MESH.md` — hypothesis H-V', falsification criteria, routing docs

### Hypothesis H-V'

> 2×2 mesh per-hop latency ≤ 1 cycle on TTIHP27a, no flit drop

### Simulation result

```
LANE V-PRIME 2x2 MESH NOC TEST PASS
  Tests passed: 19 / 19
```

### Key facts

| Property | Value |
|----------|-------|
| Dies | 4 |
| Topology | 2×2 grid, XY routing |
| Per-hop latency | 1 clock cycle |
| Max hops | 2 (opposite corner) |
| `*` operators | 0 (R-SI-1 CLEAN) |
| Lane A' modified | NO (R18 LAYER-FROZEN) |
| Scale-out vs single die | ×4 (Lever #3) |

Extends Lane A' (`holo_noc_1cycle.sv`, Wave-27, `ebd426d9`).

---

## Previous lanes

| Lane | Wave | File | Status |
|------|------|------|--------|
| Y  | — | `rtl/holo_mux_1x2.sv` | ✅ |
| A' | 27 | `rtl/holo_noc_1cycle.sv` | ✅ |
| B' | — | `rtl/holo_razor_ff.sv` | ✅ |
| C' | — | `rtl/holo_opcode_DE_decoder.sv` | ✅ |
| V' | 28 | `rtl/holo_noc_2x2_mesh.sv` | ✅ |

---

```
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
```
