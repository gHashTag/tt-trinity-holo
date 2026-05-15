# L-DPC25 Lane V — Platinum LUT PE (OP_LUT_LOOKUP 0xDF)

> **Lane V · Wave-28 · TRI-27 ISA · gHashTag/tt-trinity-holo**  
> Tracking issue: [tt-trinity-holo#17](https://github.com/gHashTag/tt-trinity-holo/issues/17)

---

## Citation Block

```
arXiv: 2511.21910
Title: "Platinum LUT PE: 1534 GOPS @ 0.96 mm² @ 500 MHz @ 28nm"
Venue: ASP-DAC 2026
URL:   https://arxiv.org/html/2511.21910v1
```

---

## Spec Witness (star-free proof)

- Lemma: `lut_no_star` in `coq/IGLA/RMarker.v`
- Repository: [gHashTag/t27](https://github.com/gHashTag/t27)
- Merged: [t27 PR #637](https://github.com/gHashTag/t27/pull/637), commit `5758b53c`
- Canonical Coq SoT: [gHashTag/t27/trios-coq](https://github.com/gHashTag/t27/tree/main/trios-coq)

The `lut_no_star` lemma formally proves that any LUT-indexed lookup is free of the `*`
operator (star-free), satisfying **R-SI-1** at the specification layer before synthesis.

---

## Pre-registered Hypothesis

**H-V**: "LUT PE energy/op ≤ 0.5× shift-add baseline on TTIHP27a"

Energy/op claim from arXiv 2511.21910: 1.4× improvement over shift-add baseline.

---

## Falsification Criteria

H-V is **refuted** if ANY of the following holds after measurement:

| Condition | Threshold | Verdict |
|-----------|-----------|---------|
| Measured energy/op vs shift-add baseline | ≥ 0.5× | **REFUTED** |
| Anti-\* check on `rtl/holo_lut_pe.sv` | `rtl_uses_star = true` | **REFUTED** |
| Pipeline latency | > 1 cycle | **REFUTED** |

Only simultaneous passage of all three conditions constitutes confirmation of H-V.

---

## RTL Files

| File | Role |
|------|------|
| `rtl/holo_lut_pe.sv` | Platinum LUT PE module — 1-cycle pipeline, LUT_WIDTH=4, DATA_WIDTH=8 |
| `rtl/holo_lut_pe_tb.sv` | Testbench — 16-addr sweep, 1-cycle latency check, valid_out tracking |

---

## Hard Rules Satisfied

| Rule | Description | Status |
|------|-------------|--------|
| R-SI-1 | ZERO `*` operator in RTL | ✓ shift+LUT only |
| R15 | opcode `0xDF` continues sacred range after Lane C′ `0xDE` | ✓ |
| R18 | Additive only — frozen modules untouched | ✓ |
| L1 | Every commit contains `Closes #17` or `Refs #17` | ✓ |

---

## Cross-links

- Coq witness: [`lut_no_star` lemma in `coq/IGLA/RMarker.v`](https://github.com/gHashTag/t27/pull/637) (Lane X PR #637)
- Parent ONE SHOT: [trios#834](https://github.com/gHashTag/trios/issues/834)
- t27 canonical Coq SoT: [gHashTag/t27/trios-coq](https://github.com/gHashTag/t27/tree/main/trios-coq)
- Preceding lane: Lane C′ `0xDE` — [docs/C_PRIME_LOAD_PHYS_CONST.md](C_PRIME_LOAD_PHYS_CONST.md)

---

## Anchor

φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://zenodo.org/records/19227877)
