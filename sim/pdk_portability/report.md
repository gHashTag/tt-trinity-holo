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

## Results (initial — fill with `make report`)

| Surface | SG13G3 gates | SG13G3 area-proxy | SKY90 gates | SKY90 area-proxy | * count both |
|---|---|---|---|---|---|
| Lane V LUT PE | N | N | N | N | 0 ← W31-G3 |
| Lane W BitROM | N | N | N | N | 0 |
| Lane V' mesh | N | N | N | N | 0 |
| Lane S sparsity | N | N | N | N | 0 |

> **Note:** `N` = not yet measured. Run `make report` in `sim/pdk_portability/`
> to populate.  Area-proxy is in µm² (Yosys internal unit, **not** routed area).

## Verdict

W31-G1 (SG13G3 clean): PASS|FAIL
W31-G2 (SKY90 clean): PASS|FAIL
W31-G3 (zero * in netlist): PASS|FAIL

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
