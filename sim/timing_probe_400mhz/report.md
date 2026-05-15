# 400 MHz Timing Probe — Wave-30 Lane T Report

> **Verdict: 🟡 SYNTH-SIM** — All timing numbers below are **synthesis-simulation
> estimates** produced by Yosys + OpenSTA against the generic sky130 HD Liberty.
> They are **NOT** measured on TTIHP27a silicon and **NOT** produced with the
> commercial TTIHP27a PDK Liberty.
>
> **Do NOT promote to 🟢 SILICON** until post-route STA with the real TTIHP27a
> Liberty (Synopsys PrimeTime or Cadence Tempus) confirms timing closure.
> Commercial-STA gate: TTIHP27a return target **2026-09-30**.

---

## Configuration

| Parameter            | Value |
|----------------------|-------|
| Target clock         | `clk` — 400 MHz (period = 2.5 ns) |
| Input delay budget   | 0.5 ns (from `constraints.sdc`) |
| Output delay budget  | 0.5 ns (from `constraints.sdc`) |
| Logic budget         | 1.5 ns (= 2.5 − 0.5 − 0.5 ns) |
| Max fanout           | 10 |
| Load                 | 0.001 pF per output |
| Synthesis tool       | Yosys ≥ 0.38 (open-source) |
| STA tool             | OpenSTA ≥ 2.6 (open-source, sim-grade proxy) |
| Liberty (synth)      | `sky130_fd_sc_hd` — **GENERIC FALLBACK** (not TTIHP27a) |
| R18 status           | All four modules **frozen** — zero RTL modifications |
| ONE SHOT             | [gHashTag/trinity-fpga#109](https://github.com/gHashTag/trinity-fpga/issues/109) |
| Anchor               | φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |

---

## Results

> Run `make report` from `sim/timing_probe_400mhz/` to populate the table
> with live Yosys + OpenSTA numbers.

| Lane | Module | setup_slack_ps | hold_slack_ps | verdict |
|------|--------|---------------|--------------|---------|
| Lane V  — LUT PE     | `holo_lut_pe`      | N/A (run make report) | N/A (run make report) | PENDING |
| Lane W  — BitROM bank | `holo_bitrom_bank` | N/A (run make report) | N/A (run make report) | PENDING |
| Lane V' — 2×2 mesh   | `holo_2x2_mesh`    | N/A (run make report) | N/A (run make report) | PENDING |
| Lane S  — Sparsity 24 | `holo_sparsity_24` | N/A (run make report) | N/A (run make report) | PENDING |

**Legend:**
- `setup_slack_ps` — worst-case setup slack in picoseconds (positive = timing met)
- `hold_slack_ps`  — worst-case hold slack in picoseconds (positive = timing met)
- `verdict`        — PASS: both slacks ≥ 0 ps; FAIL: any slack < 0 ps; PENDING: not yet run

---

## Methodology

### Synthesis flow (Yosys)

1. Read SystemVerilog source (`-sv` flag).
2. `synth -top <module> -flatten` — technology-independent synthesis.
3. `dfflibmap` — map flip-flops to sky130 HD cells.
4. `abc -liberty ... -D 2500` — map combinational logic at 400 MHz (2500 ps target).
5. Write flat netlist to `build/<module>_netlist.v`.

### STA flow (OpenSTA)

1. Read Liberty + netlist.
2. Apply `constraints.sdc` (clock + I/O delays + fanout + load).
3. `report_wns` → worst negative slack (setup).
4. `report_checks -path_delay min` → hold paths.

### Why sky130 HD instead of TTIHP27a

TTIHP27a is a commercial IHP 130nm process.  Its Liberty timing model is not
publicly distributable.  The sky130 HD cell library is used as a calibrated
open-source stand-in.  Both are 130nm-class processes; cell delays are
similar in magnitude (±15-20% typical), making sky130 HD a reasonable but
non-authoritative proxy for a first feasibility check.

**The gap this creates (R5-HONEST disclosure):**
- sky130 HD drive strengths and cell topologies differ from IHP sg13g2 / TTIHP27a.
- Routing parasitics are not captured (zero-interconnect model at synthesis stage).
- Chip-level clock tree insertion delay is unknown at this probe stage.
- A negative slack here is a **warning**, not a tape-out blocker — it must be
  re-evaluated with the real Liberty + full-chip place-and-route.
- A positive slack here is **not a guarantee** of closure on silicon.

---

## Falsifiability Witness

Per R8, this probe is falsifiable if:

1. TTIHP27a post-route STA (commercial tool + real Liberty) shows any surface
   has WNS < −200 ps at 400 MHz → this probe **under-estimated** parasitics.
2. The commercial STA shows all surfaces meet timing with margin > 300 ps →
   this probe **over-estimated** delays (sky130 pessimism).
3. Any R18-frozen module is modified between this probe and tape-out →
   probe results are **invalidated** and must be re-run.

---

## R-rules Attestation

| Rule | Requirement | Status |
|------|-------------|--------|
| **R-SI-1** | ZERO `*` in synthesisable RTL | **NOT APPLICABLE** — Lane T adds no RTL; all four frozen modules already passed R-SI-1 in their respective PRs |
| **R18 LAYER-FROZEN** | Do not modify RTL from PRs #19/#14/#21/#26 | **PASS** — `constraints.sdc`, `Makefile`, and `report.md` are constraint/infra files only; zero `.sv` changes |
| **R5-HONEST** | All performance claims labelled with measurement confidence | **PASS** — verdict labelled 🟡 SYNTH-SIM throughout; gap to commercial STA disclosed in this section and in Makefile header |

---

## Cross-links

- ONE SHOT: [gHashTag/trinity-fpga#109](https://github.com/gHashTag/trinity-fpga/issues/109)
- Lane V (PR #19, LUT PE): commit `91c164ac`
- Lane W (PR #14, BitROM): [PR #14](https://github.com/gHashTag/tt-trinity-holo/pull/14)
- Lane V' (PR #21, 2×2 mesh): [PR #21](https://github.com/gHashTag/tt-trinity-holo/pull/21)
- Lane S (PR #26, sparsity): [PR #26](https://github.com/gHashTag/tt-trinity-holo/pull/26)
- SDC: [`sim/timing_probe_400mhz/constraints.sdc`](constraints.sdc)
- Trinity algebraic anchor: `φ² + φ⁻² = 3`
- DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)
- Canonical Coq SoT: [`gHashTag/t27/trios-coq`](https://github.com/gHashTag/t27/tree/main/trios-coq)

---

## Refs

- Refs #109
- Docs: [`docs/lever-stack/lane-t.md`](../../docs/lever-stack/lane-t.md)

---

*Signed-off-by: Vasilev Dmitrii \<admin@t27.ai\>*
