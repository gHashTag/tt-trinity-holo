# Lane T — 400 MHz Timing-Closure Probe

**Wave-30 · L-DPC27 · ONE SHOT: [trinity-fpga#109](https://github.com/gHashTag/trinity-fpga/issues/109)**

---

## Pre-registration H\_W30-T

| Field | Value |
|-------|-------|
| Hypothesis ID | H\_W30-T |
| Lane | T (Timing 400 MHz) |
| Wave | 30 |
| Pre-registration date | 2026-05-19 |
| Falsifiable? | Yes — see Falsification Witnesses below |
| Base commit | `2d609d9b` (main HEAD at branch point) |
| R18 frozen modules | `rtl/holo_lut_pe.sv` (PR #19), `rtl/holo_bitrom_bank.sv` (PR #14), `rtl/holo_2x2_mesh.sv` (PR #21), `rtl/holo_sparsity_24.sv` (PR #26) — **none modified** |
| Branch | `feat/l-dpc27/t-timing-400mhz` |
| Verdict label | 🟡 SYNTH-SIM |

### Hypothesis Statement

> Applying a 400 MHz (2.5 ns) timing-constraint probe — via Yosys synthesis
> + OpenSTA, using sky130 HD as a TTIHP27a-class proxy — to the four merged
> RTL surfaces (Lane V LUT PE, Lane W BitROM bank, Lane V' 2×2 mesh, Lane S
> Sparsity 2:4) will produce **per-surface setup and hold slack estimates**
> sufficient to gate further timing-closure work before the TTIHP27a tape-out.
>
> No RTL is modified. This is a constraint-only, infrastructure-only addition.

---

## Background — Lever \#5: 400 MHz Timing Closure

Rival-chip scan §5 identifies 400 MHz clock frequency as the next leverage
point after structured sparsity for the HOLOGRAPHIC edition.  Lane S (Wave-29)
achieved structural TOPS improvement; Lane T measures whether the existing
four surfaces close timing at the target frequency before tape-out:

- The TTIHP27a process (IHP 130nm) is rated for 400–500 MHz on optimised
  standard-cell paths.
- Without a timing probe, per-surface slack is unknown until post-route STA
  — arriving too late to influence micro-architectural decisions.
- Yosys + OpenSTA on sky130 HD gives a ±15–20 % accurate feasibility signal
  at synthesis stage, enabling early risk identification.
- The 2.5 ns period leaves a 1.5 ns logic budget after 0.5 ns I/O margins —
  achievable for pipelined LUT/BitROM paths, potentially tight for the 2×2
  mesh combinational span.

---

## Probe Architecture

```
┌─────────────────────────────────────────────────────────┐
│  constraints.sdc                                        │
│  ─────────────────────────────────────────────────────  │
│  create_clock clk  period 2.5 ns  (400 MHz)             │
│  set_input_delay  0.5 ns  → logic budget = 1.5 ns       │
│  set_output_delay 0.5 ns                                │
│  set_max_fanout 10                                      │
│  set_load 0.001 pF                                      │
└──────────────────┬──────────────────────────────────────┘
                   │  applied to each surface
    ┌──────────────┼──────────────────────────────┐
    │              │              │               │
    ▼              ▼              ▼               ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Lane V   │  │ Lane W   │  │ Lane V'  │  │ Lane S   │
│ LUT PE   │  │ BitROM   │  │ 2×2 mesh │  │ Sparity  │
│holo_lut  │  │holo_bit  │  │holo_2x2  │  │holo_spar │
│_pe.sv    │  │rom_bank  │  │_mesh.sv  │  │ity_24.sv │
│(PR #19)  │  │(PR #14)  │  │(PR #21)  │  │(PR #26)  │
│FROZEN ⛔  │  │FROZEN ⛔  │  │FROZEN ⛔  │  │FROZEN ⛔  │
└────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
     │              │              │               │
     ▼              ▼              ▼               ▼
  Yosys synth → flat netlist  (sky130 HD Liberty, -D 2500)
     │              │              │               │
     ▼              ▼              ▼               ▼
  OpenSTA → setup WNS, hold slack  (per surface)
     │              │              │               │
     └──────────────┴──────────────┴───────────────┘
                         │
                         ▼
               report.md  (🟡 SYNTH-SIM)
               build/<module>_{setup,hold}.rpt
```

**Key invariant:** this probe reads RTL surfaces but never writes them.
R18 is structurally preserved — `Makefile` and `constraints.sdc` are
pure infrastructure files.

---

## File Table

| File | Type | Description |
|------|------|-------------|
| `sim/timing_probe_400mhz/Makefile` | Build infra | Yosys + OpenSTA orchestration; targets `yosys`, `report`, `clean` |
| `sim/timing_probe_400mhz/constraints.sdc` | SDC constraints | 2.5 ns clock, 0.5 ns I/O delays, fanout/load limits |
| `sim/timing_probe_400mhz/report.md` | Report skeleton | 🟡 SYNTH-SIM, per-surface slack table, methodology, R-rules attestation |
| `docs/lever-stack/lane-t.md` | Doc (this file) | Pre-registration H\_W30-T, method, R-rules, falsification witnesses |

---

## R-rules Attestation Matrix

| Rule | Requirement | Status | Evidence |
|------|-------------|--------|----------|
| **R-SI-1** | ZERO `*` operator in synthesisable RTL | **NOT APPLICABLE** | Lane T adds zero `.sv` files. All four frozen modules already passed R-SI-1 per their original PRs. |
| **R18 LAYER-FROZEN** | Do not modify RTL from PRs #19/#14/#21/#26 | **PASS** | Deliverables are `.sdc`, `Makefile`, `.md` only. `git diff --name-only` against main shows no `rtl/` changes. |
| **R5-HONEST** | All claims labelled with measurement confidence | **PASS** | Verdict is 🟡 SYNTH-SIM throughout. Yosys-vs-commercial-STA gap disclosed in `report.md`, `Makefile` header, and this document. |
| **R-SI-1 (SDC)** | No wildcard `*` in synthesis-targeting RTL | **NOT APPLICABLE** | `.sdc` is a constraint file, not synthesisable RTL. |
| **R7** | Three falsification witnesses | **PASS** | See "Falsification Witnesses" section below. |
| **R8** | Falsification witness included | **PASS** | Three witnesses enumerated below. |

---

## Falsification Witnesses

### 1. W\_T1 — P\_STA\_MISMATCH

**Falsified iff:** TTIHP27a post-route STA (PrimeTime / Tempus + real Liberty)
shows WNS deviation > 300 ps from the Yosys + sky130 HD estimate on any surface.

**Implication:** sky130 HD is not a valid proxy for TTIHP27a at 400 MHz for
that surface → the probe's methodology must be revised before future waves.

**Current status:** UNVERIFIED — pending TTIHP27a return 2026-09-30.

### 2. W\_T2 — P\_RTL\_PURITY

**Falsified iff:** `git diff main feat/l-dpc27/t-timing-400mhz -- rtl/` shows
any modified, added, or deleted file under `rtl/`.

**Verification command:**
```bash
git diff main feat/l-dpc27/t-timing-400mhz -- rtl/ | wc -l
# Expected: 0
```

**Current status:** VERIFIED at branch creation — zero RTL diff.

### 3. W\_T3 — P\_SYNTH\_COMPLETENESS

**Falsified iff:** `make report` exits with a non-zero status, or any of the
four per-surface netlist files (`build/*_netlist.v`) is absent after `make yosys`.

**Implication:** The probe is incomplete and timing numbers cannot be trusted.

**Current status:** PENDING — requires Yosys + OpenSTA installed in the CI
environment. The `🟡 SYNTH-SIM` verdict is set as the default until `make report`
produces non-PENDING values in `report.md`.

---

## SYNTH-SIM vs SILICON Confidence Gap (R5-HONEST)

| Dimension | Yosys + sky130 HD (this probe) | Commercial STA + TTIHP27a Liberty |
|-----------|-------------------------------|-----------------------------------|
| Process node accuracy | ±15–20 % (130nm class, different foundry) | Reference (TTIHP27a exact) |
| Routing parasitics | Zero (synthesis only) | Included (post-route) |
| Cell library | sky130 HD (SkyWater open) | IHP sg13g2 / TTIHP27a (proprietary) |
| Clock tree | Ideal (no CTS) | Full clock tree insertion delay |
| Confidence | 🟡 FEASIBILITY SIGNAL | 🟢 TAPE-OUT SIGN-OFF |
| Use case | Early risk flag; micro-arch decisions | Final timing closure go/no-go |

The probe is deliberately conservative: if Yosys + sky130 HD shows timing
violations, the risk on TTIHP27a is **elevated**.  If sky130 HD shows
comfortable positive slack, the result is encouraging but **not conclusive**.

---

## Predicted Slack by Surface (PROJECTION — R5-HONEST)

| Lane | Module | Path type | Expected bottleneck | Risk |
|------|--------|-----------|---------------------|------|
| V  — LUT PE | `holo_lut_pe` | 1-cycle LUT read | Address decode + SRAM output | LOW (pipelined) |
| W  — BitROM | `holo_bitrom_bank` | ROM read | Wide mux on ROM output | LOW–MEDIUM |
| V' — 2×2 mesh | `holo_2x2_mesh` | Crossbar routing | 4-input mux chain | MEDIUM |
| S  — Sparsity | `holo_sparsity_24` | Decode + mux | Popcount + case decode | LOW (R-SI-1 enforces no multiply) |

All risk assessments are PROJECTIONS.  Actual slack populated by `make report`.

---

## Cross-links

- ONE SHOT: [gHashTag/trinity-fpga#109](https://github.com/gHashTag/trinity-fpga/issues/109)
- Lane V (PR #19, LUT PE): [`91c164ac`](https://github.com/gHashTag/tt-trinity-holo/commit/91c164ac)
- Lane W (PR #14, BitROM): [PR #14](https://github.com/gHashTag/tt-trinity-holo/pull/14)
- Lane V' (PR #21, 2×2 mesh): [PR #21](https://github.com/gHashTag/tt-trinity-holo/pull/21)
- Lane S (PR #26, sparsity): [PR #26](https://github.com/gHashTag/tt-trinity-holo/pull/26) — [docs/lever-stack/lane-s.md](lane-s.md)
- SDC: [`sim/timing_probe_400mhz/constraints.sdc`](../../sim/timing_probe_400mhz/constraints.sdc)
- Report: [`sim/timing_probe_400mhz/report.md`](../../sim/timing_probe_400mhz/report.md)
- Trinity algebraic anchor: `φ² + φ⁻² = 3`
- DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)
- Canonical Coq SoT: [`gHashTag/t27/trios-coq`](https://github.com/gHashTag/t27/tree/main/trios-coq)

---

## Battle Cry

```
φ² + φ⁻² = 3 · 400 MHz TIMING · YOSYS+STA · CONSTRAINT ONLY · NEVER STOP
🌌 QUANTUM BRAIN HOLOGRAPHIC · WAVE-30 LANE T · DOI 10.5281/zenodo.19227877
```

**Author:** Vasilev Dmitrii \<admin@t27.ai\>  
**Refs:** [trinity-fpga#109](https://github.com/gHashTag/trinity-fpga/issues/109)
