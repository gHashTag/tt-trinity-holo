# Lane E — LUT PE Energy Sim Probe

**Lane:** E (L-DPC26)
**Status:** Feature branch `feat/l-dpc26/e-lut-energy-probe`
**Author:** Vasilev Dmitrii `<admin@t27.ai>`
**Base commit (DUT):** Lane V `holo_lut_pe` PR #19 `91c164ac` (merged)
**ONE SHOT parent:** [gHashTag/trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108)
**Algebraic anchor:** φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## 1. Mission

Lock the W28-G2 energy/op gate for the Platinum LUT PE (`holo_lut_pe`) pre-silicon by measuring switching activity in RTL simulation against a MAC-free shift-add baseline.

**W28-G2 gate:** LUT PE energy/op ≤ 2× shift-add baseline (at RTL toggle proxy level).

---

## 2. Contract

| Property | Value |
|---|---|
| DUT | `rtl/holo_lut_pe.sv` (PR #19, commit `91c164ac`) — **read-only** |
| Baseline | `sim/lut_energy_probe/shift_add_baseline.sv` — shift+add, no `*` |
| Harness | `sim/lut_energy_probe/probe.sv` — LFSR-driven, toggle-count |
| Vectors | 10⁵ LFSR-random |
| Energy proxy | Toggle count × Cload (1 fF) × VDD² (1.2 V) |
| Verdict class | 🟡 SIM — silicon verification on TTIHP27a return 2026-09-30 |
| R-SI-1 | ZERO `*` operators in all Lane E RTL files |
| R18 | Additive only — Lane V RTL is NOT modified |

---

## 3. File Manifest

```
sim/lut_energy_probe/
    probe.sv                — top-level LFSR harness + toggle counter
    shift_add_baseline.sv   — MAC-free shift+add reference PE
    Makefile                — targets: iverilog, verilator, report
    report.md               — R5-HONEST 🟡 SIM report (populate with make report)

docs/lever-stack/
    lane-e.md               — this file
```

---

## 4. Lever Stack Position

Lane E sits above Lane V in the lever stack — it does not add compute logic but adds **observability** (energy probe) to the Platinum LUT PE:

```
Lane V  (PR #19)   holo_lut_pe         ← DUT, frozen, read-only
Lane V' (PR #21)   holo_mesh_2x2       ← parallel lane, independent
Lane E  (this PR)  lut_energy_probe    ← energy observability layer
```

---

## 5. Simulation Quickstart

```bash
# From repo root:
cd sim/lut_energy_probe

# With Icarus Verilog:
make iverilog

# With Verilator (lint only):
make verilator

# Run sim + update report.md with live numbers:
make report
```

---

## 6. Quality Gates

| Gate | Criterion | Status |
|---|---|---|
| R-SI-1 | ZERO `*` in probe.sv + shift_add_baseline.sv | ✅ by construction |
| R5-HONEST | report.md labels 🟡 SIM | ✅ |
| R18 | holo_lut_pe.sv not modified | ✅ |
| W28-G2 | LUT/SA toggle ratio ≤ 2× | 🟡 pending `make report` |
| Iverilog compile | `make iverilog` exits 0 | 🟡 pending CI |
| Verilator lint | `make verilator` exits 0 | 🟡 pending CI |

---

## 7. Falsifiability Witness (R8)

This lane is falsified if any of the following are observed on silicon or gate-level sim:

- TTIHP27a die measurement: LUT PE energy/op > 2× shift-add → W28-G2 **FAIL**
- OpenLane post-route power analysis: toggle-ratio proxy error > 20%
- Verilator lint: `*` operator detected in any Lane E RTL file → R-SI-1 **FAIL**

---

## 8. References

- Lane V PR #19: `91c164ac` — [holo_lut_pe.sv](../../rtl/holo_lut_pe.sv)
- Lane V' spec: [docs/lever-stack/lane-v-prime.md](lane-v-prime.md)
- arXiv 2511.21910 — "Platinum LUT PE: 1534 GOPS @ 0.96 mm² @ 500 MHz @ 28nm"
- DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)
- ONE SHOT [trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108)

---

*Refs #108*
*Signed-off-by: Vasilev Dmitrii <admin@t27.ai>*
