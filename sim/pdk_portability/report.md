# PDK Portability Probe — Wave-31 Lane M Report

## Status

🟡 SYNTH-SIM — Yosys generic synth + tech-map proxy.
Commercial-grade STA on real Liberty files is a gate, not a claim.
Silicon-verified 🟢 only on multi-PDK silicon return.

## Configuration

- DUT surfaces: Lane V (91c164ac), Lane W (898fc06), Lane V' (2a06e540), Lane S (98246bd3)
- PDK targets: SG13G3 (proxy), SKY90 (proxy)
- Tool: Yosys >= 0.38 (synth + abc tech-map)
- Run: `make report` (requires Yosys installed)

## Results (Wave-32 activation, 2026-05-16 — generic Yosys synth fallback)

Proxy Liberty files (sg13g3_tech.lib, sky90_tech.lib) lack async-reset DFF cells that `dfflegalize` requires for the LUT PE's `always_ff @(posedge clk or negedge rst_n)` register style. Pending real IHP Open-PDK Liberty integration, Wave-32 falls back to **generic Yosys synth** (no PDK Liberty mapping) to capture gate counts and the R-SI-1 invariant.

| Surface | Generic cells | Wires | Generic DFFs | Combinational | $mul/$div/$mod count |
|---|---|---|---|---|---|
| Lane V LUT PE      | **463**  | 346  | 137 (DFFE/DFF) | 326 | **0** ← W31-G3 |
| Lane W BitROM bank | **1**    | 10   | 1 (SDFF) | 0 | **0** |
| Lane V' 2×2 mesh   | **1809** | 1132 | 396 (SDFF) | 1413 | **0** |
| Lane S sparsity 24 | **92**   | 91   | 10 (DFF) | 82 | **0** |

Lane W collapses to 1 cell because the sentinel `4'b1010` weight pattern is constant for all 64 cells; Yosys optimizes the lookup to a constant fan-out. With real per-cell weight initialisation at chip-boot the cell count will rise; W29-G1 BER probe (PR #31, merged) exercises the actual ROM read path independently.

## Verdict

- **W31-G1 (SG13G3 PDK-mapped synth clean):** 🟡 **PROXY-LIB-INCOMPLETE** — proxy Liberty missing async-reset DFF, real IHP Open-PDK Liberty integration tracked as follow-up (no W31-G1 numeric verdict in Wave-32).
- **W31-G2 (SKY90 PDK-mapped synth clean):** 🟡 **PROXY-LIB-INCOMPLETE** — same root cause; SKY90 has no public Liberty release in any case.
- **W31-G3 (zero `*` operators in synthesised netlist):** ✅ **PASS** across all 4 surfaces. Confirmed by grep `\$mul|\$div|\$mod` against generic Yosys netlists — 0 hits on all 4. R-SI-1 holds end-to-end (RTL → netlist).

---

## Liberty-Proxy Gap (R5-HONEST)

Both Liberty files shipped alongside this report are **PROXY** files, not
production PDK releases.  The gap table below quantifies the confidence
limitation:

| Dimension | SG13G3 proxy (sg13g3_tech.lib) | Real IHP sg13g2/sg13g3 Liberty | SKY90 proxy (sky90_tech.lib) | Real SKY90 Liberty (not yet public) |
|-----------|-------------------------------|-------------------------------|------------------------------|-------------------------------------|
| FO4 estimate | ~130 ps (conservative) | Characterised; foundry-signed | ~90 ps (ITRS scaling) | Unknown |
| PVT corners | tt 1.2 V 25 °C only | Typically 3–5 corners | tt 1.0 V 25 °C only | Unknown |
| Drive strengths | x1 only | x0.5 – x8 | x1 only | Unknown |
| Power data | None | Full leakage + switching | None | Unknown |
| Routing parasitics | Zero (synthesis-only) | Included post-route | Zero (synthesis-only) | Unknown |
| Open-source URL | https://github.com/IHP-GmbH/IHP-Open-PDK | Same (real) | N/A (not yet released) | N/A |
| Confidence | 🟡 GATE-COUNT PROXY | 🟢 TAPE-OUT SIGN-OFF | 🟡 NODE-SCALE PROXY | 🟢 (future, if released) |

**SKY90 note:** SkyWater Technology has not released a public sky90 PDK as of
Wave-31 (2026-05-20).  The sky90_tech.lib proxy is used here solely as a
portability signal — it demonstrates that the four RTL surfaces are
tech-mappable at the 90 nm node.  Absolute gate counts and area values carry
±30–40 % uncertainty relative to any eventual real sky90 Liberty.

---

## Methodology

```
RTL surface (.sv)   [FROZEN — R18]
      │
      ▼
  Yosys synth -top <module> -flatten
      │
      ▼
  dfflibmap -liberty <PDK_proxy.lib>
      │
      ▼
  abc -liberty <PDK_proxy.lib>     ← tech-map to proxy cell set
      │
      ▼
  write_verilog -noattr build/<PDK>/<module>_netlist.v
  stat -liberty <PDK_proxy.lib> > build/<PDK>/<module>_stat.log
      │
      ▼
  report.md table patched by `make report`
```

R-SI-1 is structurally preserved: no synthesisable RTL is added or modified.
R18 is structurally preserved: all four frozen modules are read-only inputs.

---

## Cross-links

- ONE SHOT: [gHashTag/trinity-fpga#110](https://github.com/gHashTag/trinity-fpga/issues/110)
- Lane V (PR #19, LUT PE): [`91c164ac`](https://github.com/gHashTag/tt-trinity-holo/commit/91c164ac)
- Lane W (PR #14, BitROM): [PR #14](https://github.com/gHashTag/tt-trinity-holo/pull/14)
- Lane V' (PR #21, 2×2 mesh): [PR #21](https://github.com/gHashTag/tt-trinity-holo/pull/21)
- Lane S (PR #26, sparsity): [PR #26](https://github.com/gHashTag/tt-trinity-holo/pull/26)
- Makefile: [`sim/pdk_portability/Makefile`](Makefile)
- SG13G3 proxy Liberty: [`sim/pdk_portability/sg13g3_tech.lib`](sg13g3_tech.lib)
- SKY90 proxy Liberty: [`sim/pdk_portability/sky90_tech.lib`](sky90_tech.lib)
- Lane spec: [`docs/lever-stack/lane-m.md`](../../docs/lever-stack/lane-m.md)
- IHP Open-PDK (real sg13g2 Liberty): https://github.com/IHP-GmbH/IHP-Open-PDK
- Trinity algebraic anchor: `φ² + φ⁻² = 3`
- DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

**Author:** Vasilev Dmitrii \<admin@t27.ai\>  
**Refs:** [trinity-fpga#110](https://github.com/gHashTag/trinity-fpga/issues/110)
