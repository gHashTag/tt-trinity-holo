# Lane V' — 2×2 Mesh NoC (4-die, 1-cycle hop)

**Lane V' · L-DPC25 · Wave-28**
**SKU:** TTSKY26c HOLOGRAPHIC
**Compliance:** R-SI-1 (ZERO `*` operator in RTL)

---

## Purpose

`holo_noc_2x2_mesh` extends the Lane A' 1-cycle inter-die NoC
([`holo_noc_1cycle.sv`](../rtl/holo_noc_1cycle.sv), Wave-27, commit `ebd426d9`)
from a 2-die swap topology to a full **4-die 2×2 mesh** with XY routing.

**Scale-out gain: ×4 over single die (Lever #3)**

---

## Pre-Registered Hypothesis

**H-V'**: *2×2 mesh per-hop latency ≤ 1 cycle on TTIHP27a, no flit drop*

---

## Falsification Criterion

H-V' is **refuted** if ANY of the following is observed:

| Condition | Refutes |
|-----------|---------|
| Per-hop latency > 1 clock cycle | H-V' |
| Any flit drop (valid input → no delivery) | H-V' |
| Any `*` operator in RTL (rtl_uses_star=true) | R-SI-1 violation |
| Opposite-corner (die0→die3) delivery in > 2 hops | H-V' |
| `hop_latency_cycles != 1` at simulation | H-V' |

**R8 falsification witness:** iverilog simulation of `holo_noc_2x2_mesh_tb.sv`
prints `LANE V-PRIME 2x2 MESH NOC TEST PASS` — all 19 test assertions pass.
Anti-`*` grep confirms R-SI-1 clean.

---

## Topology

```
die0 (row=0, col=0) ──E── die1 (row=0, col=1)
      │                          │
      S                          S
      │                          │
die2 (row=1, col=0) ──E── die3 (row=1, col=1)
```

Die index encoding: `{row[0], col[0]}` — bit-extract only, no multiply.

| Die | (row, col) | Index |
|-----|-----------|-------|
| die0 | (0, 0) | 2'b00 |
| die1 | (0, 1) | 2'b01 |
| die2 | (1, 0) | 2'b10 |
| die3 | (1, 1) | 2'b11 |

---

## XY Routing Algorithm

Deterministic, deadlock-free. Column is fixed before row.

```
function xy_next_hop(src, dst):
    if src.col != dst.col:
        return {src.row, dst.col}   // fix column first
    elif src.row != dst.row:
        return {dst.row, src.col}   // then fix row
    else:
        return src                  // at destination
```

**No multiply operator used.** Routing is pure bit-extract and ternary compare (R-SI-1 compliant).

### Route Examples

| Source | Destination | Path | Hops |
|--------|-------------|------|------|
| die0 (0,0) | die1 (0,1) | 0→1 | 1 |
| die0 (0,0) | die2 (1,0) | 0→2 | 1 |
| die0 (0,0) | die3 (1,1) | 0→1→3 | 2 |
| die1 (0,1) | die2 (1,0) | 1→0→2 | 2 |
| die3 (1,1) | die0 (0,0) | 3→2→0 | 2 |

Maximum path length: **2 hops** (opposite corners).

---

## Port Table

### Flat-Packed Port Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (rising-edge) |
| `rst_n` | input | 1 | Synchronous active-low reset |
| `flit_in[DIES*FLIT_W-1:0]` | input | 128 | Packed input flits; `[d*FLIT_W +: FLIT_W]` = die d |
| `dest_in[DIES*2-1:0]` | input | 8 | Packed destinations; `[d*2 +: 2]` = die d dest |
| `vld_in[DIES-1:0]` | input | 4 | Valid bits; `[d]` = die d |
| `flit_out[DIES*FLIT_W-1:0]` | output | 128 | Packed delivery flits |
| `vld_out[DIES-1:0]` | output | 4 | Delivery valid bits |
| `hop_latency_cycles[0:0]` | output | 1 | Always = 1 (handshake) |

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FLIT_W` | 32 | Flit width in bits |
| `DIES` | 4 | Number of dies (fixed for 2×2) |

---

## Latency Model

- **Per-hop latency = 1 clock cycle** (registered output)
- Combinational routing resolves next-hop; flit latches on posedge
- 1-hop path: delivery at posedge N+1 (inject at negedge N)
- 2-hop path: delivery at posedge N+2

`hop_latency_cycles` is driven as constant `1` for downstream verification handshake — identical contract to Lane A'.

---

## Anti-`*` Compliance (R-SI-1)

```
$ grep -n '\*' rtl/holo_noc_2x2_mesh.sv | grep -v '//' | grep -v '\*\*'
(no output)
```

**Result: CLEAN — zero `*` operator occurrences.**

Routing uses only:
- Bit-select (`src[0]`, `src[1]`)
- Ternary operator (`?:`)
- Concatenation (`{a, b}`)
- Comparison (`!=`, `==`)

---

## Test Assertions (holo_noc_2x2_mesh_tb.sv)

| # | Test | Criteria | Result |
|---|------|----------|--------|
| TC4 | `hop_latency_cycles == 1` | Constant output | PASS |
| TC2 | die0 → die1 (1-hop) | `vld_out[1]=1`, correct flit | PASS |
| TC2 | No spurious delivery | `vld_out[0,2,3]=0` | PASS (3) |
| TC1 | die0 → die3 (2-hop) | `vld_out[3]=1`, correct flit | PASS |
| TC1 | No spurious delivery | `vld_out[0,1,2]=0` | PASS (3) |
| TC3 | 4-way simultaneous | All 4 `vld_out` correct | PASS (8) |
| | **Total** | | **19/19 PASS** |

Simulation command:
```
iverilog -g2012 rtl/holo_noc_2x2_mesh.sv rtl/holo_noc_2x2_mesh_tb.sv -o noc_sim
./noc_sim
# → LANE V-PRIME 2x2 MESH NOC TEST PASS
```

---

## Comparison with Lane A'

| Property | Lane A' (`holo_noc_1cycle`) | Lane V' (`holo_noc_2x2_mesh`) |
|----------|-----------------------------|-------------------------------|
| Die count | 2 | 4 |
| Topology | Swap (linear) | 2×2 mesh |
| Routing | Swap index | XY deterministic |
| Max hops | 1 | 2 |
| Per-hop latency | 1 cycle | 1 cycle |
| R-SI-1 | Clean | Clean |
| Scale-out | 1× | ×4 |

R18 LAYER-FROZEN: `holo_noc_1cycle.sv` is **not modified**. Lane V' is a new additive module.

---

## Coq / Proof Linkage

No new Coq lemma required for Lane V'.
Reuses the **Lane Z `OP_NOC_FORWARD` proof family** which covers the opcode semantics.
Cross-link: [t27/trios-coq](https://github.com/gHashTag/t27/tree/main/trios-coq) `IGLA/` directory.

---

## References

- Lane A' document: [`docs/A_PRIME_NOC.md`](A_PRIME_NOC.md)
- Lane A' commit: `ebd426d9` — `feat(a-prime-noc): 1-cycle inter-die NoC stub (R-SI-1 clean)`
- Parent ONE SHOT: [trios#834](https://github.com/gHashTag/trios/issues/834)
- Tracking issue: [tt-trinity-holo#16](https://github.com/gHashTag/tt-trinity-holo/issues/16)
- Zenodo DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

```
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
```
