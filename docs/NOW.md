# NOW — tt-trinity-holo Active Lanes

This file tracks the currently active RTL lanes on `gHashTag/tt-trinity-holo`.

---

## Lane T — TENET Sparsity-Aware LUT Skip (OP_SPARSE_SKIP 0xE1) · L-DPC29 Wave-33

**Status:** filed on branch `feat/wave33-tenet-lane-t`
**Tracking issue:** [gHashTag/trinity-fpga#114](https://github.com/gHashTag/trinity-fpga/issues/114)
**Opcode:** `0xE1` (sacred range, continues after Lane W `0xE0`)
**Coq witness (Lane T'):** [gHashTag/t27 PR #645](https://github.com/gHashTag/t27/pull/645) merged `8eb3ac13`
**Strategic ref:** trios `docs/strategic/TOPS-LEVERS-2026-05-16-001.md`

### New files

| File | Lines | Description |
|------|------:|-------------|
| `rtl/holo_sparse_skip.sv` | ~140 | TENET sparsity-aware LUT skip controller; sliding-window zero count, threshold comparator, single-bit `skip_o` output |
| `sim/sparse_skip_probe/probe.sv` | ~95 | iverilog testbench: 10000 cycles of 2:4 popcount-2 masks, counts skip-rate |
| `sim/sparse_skip_probe/Makefile` | ~30 | sv2v + iverilog build |
| `sim/sparse_skip_probe/report.md` | ~90 | W33-G1 (no `*`) + W33-G4 (≥250/1000 skip-rate) verdict report 🟡 SIM |

### Wave-33 G1 + G4 results

- **W33-G1 (zero `*` in synth):** 102 cells in Yosys generic synth · 0 `$mul/$div/$mod` ✅ PASS
- **W33-G4 (skip-rate ≥ 250/1000):** 1000/1000 parts-per-thousand · ✅ PASS 🟡 SIM

---

## Lane V — Platinum LUT PE (OP_LUT_LOOKUP 0xDF) · L-DPC25 Wave-28

**Status:** delivered on branch `feat/lane-v-platinum-lut-pe`  
**Tracking issue:** [tt-trinity-holo#17](https://github.com/gHashTag/tt-trinity-holo/issues/17)  
**Opcode:** `0xDF` (sacred range, continues after Lane C′ `0xDE`)

### New files

| File | Lines | Description |
|------|-------|-------------|
| `rtl/holo_lut_pe.sv` | 97 | Platinum LUT PE module — 1-cycle pipeline, `LUT_WIDTH=4`, `DATA_WIDTH=8`, zero `*` operator |
| `rtl/holo_lut_pe_tb.sv` | 206 | Testbench — 16-addr sweep, 1-cycle latency, valid_out tracking, prints LANE V LUT PE TEST PASS |
| `docs/L_DPC25_LANE_V_LUT_PE.md` | 85 | Lane V README — citation, H-V hypothesis, falsification criteria, cross-links |
| `docs/NOW.md` | this file | Active lane tracker |

### References
- arXiv [2511.21910](https://arxiv.org/html/2511.21910v1) — ASP-DAC 2026 "Platinum LUT PE: 1534 GOPS @ 0.96 mm² @ 500 MHz @ 28nm"
- Spec witness: `lut_no_star` lemma in [t27 PR #637](https://github.com/gHashTag/t27/pull/637)
- Parent ONE SHOT: [trios#834](https://github.com/gHashTag/trios/issues/834)

### Hard rules
- **R-SI-1**: zero `*` operator — shift+LUT only
- **R15**: opcode `0xDF` continues sacred range after Lane C′ `0xDE`
- **R18**: additive only, frozen modules untouched
- **L1**: all commits cite `Closes #17`

---

## Lane C′ — LOAD_PHYSICS_CONST (OP `0xDE`) · L-DPC24

See [docs/C_PRIME_LOAD_PHYS_CONST.md](C_PRIME_LOAD_PHYS_CONST.md).

---

## Lane B-FIX — Wave-32 BitROM BER probe truncation fix

6'(64) wrapped to 0 → no reads counted. 32-bit comparison restores all 64 cells in-range. BER=0/1e6, W29-G1 PASS. Refs #108.

---

## Wave-32 PROBE ACTIVATION — verdict aggregate

- W29-G1 BitROM BER ≤ 1e-9: ✅ PASS 🟡 SIM (1e6 reads, 0 errors)
- W29-G2 LUT/SA energy ≤ 2×: ✅ PASS 🟡 SIM (ratio 0.666×)
- W30-G1…G4 400 MHz STA: 🟡 STA-PENDING (synth OK 4/4; OpenSTA+Liberty not in sandbox)
- W31-G1/G2 PDK-mapped synth: 🟡 PROXY-LIB-INCOMPLETE (async-reset DFF missing in proxy libs)
- W31-G3 zero `*` in netlist: ✅ PASS 4/4 surfaces. R-SI-1 holds RTL→netlist.

Refs #108 #109 #110.

---

Anchor: φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://zenodo.org/records/19227877)
