# Lane M — Multi-PDK Portability Probe

**Wave-31 · L-DPC28 · ONE SHOT: [trinity-fpga#110](https://github.com/gHashTag/trinity-fpga/issues/110)**

---

## Pre-registration H\_W31-M

| Field | Value |
|-------|-------|
| Hypothesis ID | H\_W31-M |
| Lane | M (Multi-PDK Portability) |
| Wave | 31 |
| Pre-registration date | 2026-05-20 |
| Falsifiable? | Yes — see Falsification Witnesses below |
| Base commit | `ba26d0a2` (main HEAD at branch point) |
| R18 frozen modules | `rtl/holo_lut_pe.sv` (PR #19), `rtl/holo_bitrom_bank.sv` (PR #14), `rtl/holo_2x2_mesh.sv` (PR #21), `rtl/holo_sparsity_24.sv` (PR #26) — **none modified** |
| Branch | `feat/l-dpc28/m-pdk-portability` |
| Verdict label | 🟡 SYNTH-SIM |

### Hypothesis Statement

> Applying Yosys synthesis and abc tech-mapping with proxy Liberty files for
> SG13G3 (IHP 130 nm) and SKY90 (90 nm node, not yet publicly released) to
> the four merged RTL surfaces (Lane V LUT PE, Lane W BitROM bank, Lane V'
> 2×2 mesh, Lane S Sparsity 2:4) will produce **per-PDK per-surface gate
> counts and area-proxy estimates** sufficient to characterise RTL
> portability across two process nodes before any multi-PDK tape-out.
>
> No RTL is modified.  This is a constraint-only, tech-map-proxy-only
> infrastructure addition.  Liberty files are proxies; the
> 🟡 SYNTH-SIM confidence level reflects the Liberty-proxy gap.

---

## Background — Lever: Multi-PDK Portability

The TRI-27 holographic chip programme targets at least two process nodes:
IHP TTIHP27a (sg13g2/sg13g3, 130 nm) and a future 90 nm tape-out candidate.
Before committing to a second PDK, the programme needs evidence that all
four merged RTL surfaces (Lanes V, W, V', S) are synthesisable and
tech-mappable under both node's cell libraries.

Lane M answers three gating questions:

1. **W31-G1** — Do all four surfaces complete Yosys synthesis + abc tech-map
   under the SG13G3 proxy Liberty without error?
2. **W31-G2** — Do all four surfaces complete Yosys synthesis + abc tech-map
   under the SKY90 proxy Liberty without error?
3. **W31-G3** — Are zero `$mul`/`$div`/`$mod` cells present in any mapped
   netlist (R-SI-1 portability sanity)?

A PASS on all three gates is a necessary (not sufficient) condition for
multi-PDK tape-out.  Sufficient condition requires production Liberty files
and post-route STA (🟢 SILICON path).

---

## Probe Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│  sim/pdk_portability/                                                  │
│  ─────────────────────────────────────────────────────────────────     │
│  Makefile          — targets: sg13g3 | sky90 | report | clean         │
│  sg13g3_tech.lib   — SG13G3 proxy Liberty (IHP 130 nm naming)         │
│  sky90_tech.lib    — SKY90 proxy Liberty  (90 nm ITRS scaling)        │
│  report.md         — 🟡 SYNTH-SIM gate-count table + gap disclosure   │
└───────────────────────────────┬────────────────────────────────────────┘
                                │  applied to each surface × each PDK
           ┌────────────────────┼────────────────────────────────────┐
           │                    │                    │               │
           ▼                    ▼                    ▼               ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │  Lane V      │  │  Lane W      │  │  Lane V'     │  │  Lane S      │
    │  LUT PE      │  │  BitROM bank │  │  2×2 mesh    │  │  Sparsity 24 │
    │holo_lut_pe   │  │holo_bitrom   │  │holo_2x2      │  │holo_sparsity │
    │  .sv (PR#19) │  │  _bank.sv    │  │  _mesh.sv    │  │  _24.sv      │
    │  FROZEN ⛔    │  │  (PR #14)⛔  │  │  (PR #21)⛔   │  │  (PR #26)⛔   │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                  │                  │
           └─────────────────┴──────────────────┴──────────────────┘
                                      │
                    ┌─────────────────┴──────────────────┐
                    │                                    │
                    ▼                                    ▼
          Yosys synth + abc                    Yosys synth + abc
          -liberty sg13g3_tech.lib             -liberty sky90_tech.lib
                    │                                    │
                    ▼                                    ▼
        build/sg13g3/<mod>_stat.log         build/sky90/<mod>_stat.log
        build/sg13g3/<mod>_netlist.v        build/sky90/<mod>_netlist.v
                    │                                    │
                    └──────────────┬─────────────────────┘
                                   │
                                   ▼
                        report.md gate-count table
                        🟡 SYNTH-SIM verdict
```

**Key invariant:** this probe reads RTL surfaces but never writes them.
R18 and R-SI-1 are structurally preserved.

---

## File Table

| File | Type | Description |
|------|------|-------------|
| `sim/pdk_portability/Makefile` | Build infra | Yosys orchestration; targets `sg13g3`, `sky90`, `report`, `clean` |
| `sim/pdk_portability/sg13g3_tech.lib` | Liberty proxy | SG13G3 proxy Liberty (IHP 130 nm naming, conservative FO4 ~130 ps) |
| `sim/pdk_portability/sky90_tech.lib` | Liberty proxy | SKY90 proxy Liberty (90 nm ITRS scaling, FO4 ~90 ps) |
| `sim/pdk_portability/report.md` | Report | 🟡 SYNTH-SIM, per-PDK gate-count table, Liberty-proxy gap table |
| `docs/lever-stack/lane-m.md` | Doc (this file) | Pre-registration H\_W31-M, method, R-rules, falsification witnesses |

---

## R-rules Attestation Matrix

| Rule | Requirement | Status | Evidence |
|------|-------------|--------|----------|
| **R-SI-1** | ZERO `*` operator in synthesisable RTL | **NOT APPLICABLE** | Lane M adds zero `.sv` files. Gate W31-G3 checks for `$mul`/`$div`/`$mod` cells in mapped netlists. |
| **R18 LAYER-FROZEN** | Do not modify RTL from PRs #19/#14/#21/#26 | **PASS** | Deliverables are `Makefile`, `.lib`, `.md` only. `git diff --name-only` against main shows no `rtl/` changes. |
| **R5-HONEST** | All claims labelled with measurement confidence | **PASS** | Verdict is 🟡 SYNTH-SIM throughout. Liberty-proxy gap fully disclosed in `report.md`, `sg13g3_tech.lib`, `sky90_tech.lib`, `Makefile` header, and this document. SKY90 non-public-PDK status explicitly stated. |
| **R7** | Three falsification witnesses | **PASS** | See "Falsification Witnesses" section below. |
| **R8** | Falsification witness included | **PASS** | Three witnesses enumerated below. |

---

## Falsification Witnesses

### 1. W\_M1 — P\_PDK\_MISMATCH

**Falsified iff:** A real production Liberty for sg13g2/sg13g3 (from IHP
Open-PDK, https://github.com/IHP-GmbH/IHP-Open-PDK) or for sky90 (when/if
released) shows gate-count deviation > 30 % from this proxy estimate on any
surface.

**Implication:** The proxy Liberty is not a valid portability signal for that
surface at that process node; the methodology must be revised before
multi-PDK tape-out decisions are made.

**Current status:** UNVERIFIED — pending real PDK Liberty availability.
The 🟡 SYNTH-SIM verdict documents this pending state.

### 2. W\_M2 — P\_RTL\_PURITY

**Falsified iff:** `git diff main feat/l-dpc28/m-pdk-portability -- rtl/`
shows any modified, added, or deleted file under `rtl/`.

**Verification command:**
```bash
git diff main feat/l-dpc28/m-pdk-portability -- rtl/ | wc -l
# Expected: 0
```

**Current status:** VERIFIED at branch creation — zero RTL diff.

### 3. W\_M3 — P\_SYNTH\_COMPLETENESS

**Falsified iff:** `make report` exits with a non-zero status, or any of the
eight per-surface-per-PDK netlist files
(`build/{sg13g3,sky90}/<module>_netlist.v`) is absent after `make report`.

**Implication:** The portability probe is incomplete and gate counts cannot be
trusted.

**Current status:** PENDING — requires Yosys >= 0.38 installed in the CI
environment.  The 🟡 SYNTH-SIM verdict is set as the default until `make report`
populates non-PENDING values in `report.md`.

---

## SYNTH-SIM vs SILICON Confidence Gap (R5-HONEST)

| Dimension | Yosys + proxy Liberty (this probe) | Commercial STA + real PDK Liberty |
|-----------|------------------------------------|-----------------------------------|
| Process node accuracy | ±20–35 % (proxy timing) | Reference (real foundry) |
| Routing parasitics | Zero (synthesis only) | Included (post-route) |
| Cell library | Hand-crafted proxy (single PVT) | Foundry-characterised (multi-PVT) |
| Clock tree | Ideal (no CTS) | Full clock tree insertion delay |
| SKY90 status | 90 nm node proxy; not a real PDK | Not yet publicly available |
| Confidence | 🟡 PORTABILITY SIGNAL | 🟢 TAPE-OUT SIGN-OFF |
| Use case | Cross-node synthesisability check | Final multi-PDK go/no-go |

The probe is deliberately conservative: if any surface fails to tech-map
under the proxy Liberty, the risk at the real PDK is **confirmed high**.
Successful mapping under a proxy is encouraging but **not conclusive**
for tape-out.

---

## Predicted Gate-Count Ratios (PROJECTION — R5-HONEST)

The gate count ratio SKY90 / SG13G3 should be approximately 0.45–0.55 for
standard CMOS at constant topology, reflecting the ~0.50× area scaling from
130 nm to 90 nm.  Significant deviations (> ±20 %) would indicate
cell-mapping differences driven by the proxy Liberty cell set rather than
genuine process scaling.

| Lane | Module | Expected SKY90/SG13G3 ratio | Note |
|------|--------|-----------------------------|------|
| V  — LUT PE | `holo_lut_pe` | ~0.50 | MUX-heavy path |
| W  — BitROM | `holo_bitrom_bank` | ~0.48 | ROM → register mapping |
| V' — 2×2 mesh | `holo_2x2_mesh` | ~0.50 | MUX crossbar |
| S  — Sparsity | `holo_sparsity_24` | ~0.52 | Case decode + AND array |

All projections are pre-`make report` ESTIMATES.  Actual values populated by
running `make report`.

---

## Cross-links

- ONE SHOT: [gHashTag/trinity-fpga#110](https://github.com/gHashTag/trinity-fpga/issues/110)
- Lane V (PR #19, LUT PE): [`91c164ac`](https://github.com/gHashTag/tt-trinity-holo/commit/91c164ac)
- Lane W (PR #14, BitROM): [PR #14](https://github.com/gHashTag/tt-trinity-holo/pull/14)
- Lane V' (PR #21, 2×2 mesh): [PR #21](https://github.com/gHashTag/tt-trinity-holo/pull/21)
- Lane S (PR #26, sparsity): [PR #26](https://github.com/gHashTag/tt-trinity-holo/pull/26)
- Lane T (Wave-30, timing probe): [docs/lever-stack/lane-t.md](lane-t.md)
- Report: [`sim/pdk_portability/report.md`](../../sim/pdk_portability/report.md)
- SG13G3 proxy Liberty: [`sim/pdk_portability/sg13g3_tech.lib`](../../sim/pdk_portability/sg13g3_tech.lib)
- SKY90 proxy Liberty: [`sim/pdk_portability/sky90_tech.lib`](../../sim/pdk_portability/sky90_tech.lib)
- IHP Open-PDK (canonical real sg13g2 Liberty): https://github.com/IHP-GmbH/IHP-Open-PDK
- Trinity algebraic anchor: `φ² + φ⁻² = 3`
- DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)
- Canonical Coq SoT: [`gHashTag/t27/trios-coq`](https://github.com/gHashTag/t27/tree/main/trios-coq)

---

## Battle Cry

```
φ² + φ⁻² = 3 · MULTI-PDK · SG13G3+SKY90 · TECHMAP PROXY · NEVER STOP
🌌 QUANTUM BRAIN HOLOGRAPHIC · WAVE-31 LANE M · DOI 10.5281/zenodo.19227877
```

**Author:** Vasilev Dmitrii \<admin@t27.ai\>  
**Refs:** [trinity-fpga#110](https://github.com/gHashTag/trinity-fpga/issues/110)
