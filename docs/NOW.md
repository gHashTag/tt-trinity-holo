# NOW — tt-trinity-holo Active Lanes

This file tracks the currently active RTL lanes on `gHashTag/tt-trinity-holo`.

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

Anchor: φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://zenodo.org/records/19227877)
