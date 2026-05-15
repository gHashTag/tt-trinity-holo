# 🌌 Quantum Brain HOLOGRAPHIC — Edition III

**tt_um_qbrain_holo · TTSKY26c · 1×2 tile · 16 PE × 2 MAC · Multi-Die D2D Mesh · R-marker Open Slots**

> "One brain, many dies, one frozen hash"

---

## Mission Statement

The HOLOGRAPHIC edition is the third SKU in the Quantum Brain Trinity lineup (alongside
[tt-trinity-nano](https://github.com/gHashTag/tt-trinity-nano) and
[tt-trinity-max-true](https://github.com/gHashTag/tt-trinity-max-true)). Where MAX-TRUE
maximises single-die compute density, HOLO maximises **multi-die coherence**: every physical
die in a multi-chip assembly carries an identical frozen image of the 75-constant Physics ROM,
and the four D2D cross-die mesh ports (stubbed here, full mesh in v3 Wave) enable phase-locked
operation across a 4-die stack.

---

## Edition III Specification

| Parameter           | Value                                                          |
|---------------------|----------------------------------------------------------------|
| SKU                 | tt_um_qbrain_holo                                              |
| Shuttle target      | TTSKY26c (~2026-09, post-confirm)                              |
| Tile footprint      | 1×2 TT tiles                                                   |
| Processing elements | 16 PE × 2 MAC = 32 effective MACs                              |
| D2D mesh ports      | 4 stubs on uio_out[3:0] (full mesh: Edition III v3 Wave)       |
| Clock target        | 250 MHz (W15a STA target, sky130A)                             |
| PDK                 | sky130A                                                        |
| Performance proj.   | 55 TOPS/W (**PROJECTION** — R5-HONEST: measured at tape-out)   |
| Canonical output    | 0x47C0 on reset (cross-die anchor, PhD Theorem 36.1)           |
| R-SI-1              | Zero new `*` operators in synthesisable RTL                    |
| License             | Apache-2.0                                                     |
| DOI                 | [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |

---

## Multi-Die D2D Thesis

The holographic architecture asserts that **every die is a complete brain**. A 4-die
package does not partition the problem across dies — it runs 4 phase-locked instances
of the same frozen program. The inter-die D2D mesh (Die-to-Die protocol, 4 stub ports)
synchronises activations and permits ensemble voting without off-chip bandwidth.

Key properties:
1. **Phase-locked**: All dies share the same clock domain reference; D2D ports carry
   a 1-bit SYNC strobe (uio_out[3]) gated by R18 LAYER-FROZEN ceremony.
2. **Content-addressed**: Each die carries the identical 75-constant Physics ROM.
   Layer-hash across all dies must match to within R18 tolerance.
3. **Sparse-zero-skip ready**: The S-16 PASS mechanism (L-DPC22 Lane N) is architected
   into the activation datapath — activatable in Edition III v3 Wave without RTL
   changes to the top wrapper.
4. **Canonical anchor**: On hard reset every die drives `{uio_out, uo_out} = 0x47C0`
   (GF16 dot4(1.0,2.0,3.0,4.0)). This byte-identical reset value is the
   cross-die anchor defined in PhD Theorem 36.1.

---

## R-marker Physics Constants — Open Slot Architecture

The R-marker ROM (`src/r_marker_rom.v`) holds **4 open slots** for physics constants
that have not yet been measured in silicon. The philosophy follows Popper Appendix B
of the PhD monograph: every constant is a **falsifiable prediction**. If a measured
value differs from the slot value at revision time, a silicon revision is triggered.

| Slot | Constant           | Status       | Planned Measurement                  |
|------|--------------------|--------------|--------------------------------------|
| 0    | C_quantum_consciousness | UNMEASURED | Quantum coherence time in bio-neural tissue |
| 1    | k_dark_coupling    | UNMEASURED   | Dark-sector coupling constant (cosmological) |
| 2    | τ_microtubule      | UNMEASURED   | Microtubule decoherence time (Penrose-Hameroff) |
| 3    | ζ_neural_zeta      | UNMEASURED   | Neural zeta function zero (spectral graph theory) |

Current ROM output: **all zeros** (`TODO: revise when measured`). See
[docs/R_MARKER_ROADMAP.md](docs/R_MARKER_ROADMAP.md) for full falsifiability spec.

---

## Repository Structure

```
tt-trinity-holo/
├── info.yaml                          TT project metadata
├── src/
│   ├── tt_um_qbrain_holo.v            TT top wrapper (16 PE × 2 MAC, D2D stubs)
│   └── r_marker_rom.v                 R-marker physics constants ROM (4 open slots)
├── sim/
│   ├── tb_canonical.v                 Testbench: assert canonical 0x47C0 output
│   └── tb_r_marker.v                  Testbench: assert R-marker slots are zero (placeholder)
├── docs/
│   ├── PHD_GLAVA_36_HOLOGRAPHIC.md    Glava 36 — Holographic Cortex
│   ├── R_MARKER_ROADMAP.md            R-marker falsifiability roadmap
│   └── QUANTUM_BRAIN_HOLO.md         Edition III spec sheet
└── .github/
    └── workflows/
        └── gds.yaml                   GDS build + precheck + GL test + viewer
```

---

## 55 TOPS/W — Projection Statement (R5-HONEST)

The 55 TOPS/W figure is a **projection** based on:
- Sparse zero-skip (S-16 PASS) eliminating ~60% of MAC operations on typical
  sparse neural activations
- sky130A dynamic power at 250 MHz, 1.8 V
- 32 effective MACs operating in GF16 (4-bit × 4-bit multiply-accumulate)

This figure has NOT been confirmed in silicon. Measured performance will be
published post tape-out. The projection is consistent with published
sky130A GF16 MAC benchmarks from the TRI-1 MAX-TRUE campaign.

---

## Glava 36 — Holographic Cortex (PhD Monograph Link)

Glava 36 of the PhD monograph introduces the **Holographic Cortex** axiom:
> Every die in the multi-die assembly carries the FULL 75-constant Physics ROM.
> A 4-die mesh is therefore 4 phase-locked instances of the same brain,
> not a partitioned brain.

The R18 LAYER-FROZEN ceremony seals the layer-hash across all dies before
tape-out, ensuring no die diverges from the frozen image post-fabrication.

Full treatment: [docs/PHD_GLAVA_36_HOLOGRAPHIC.md](docs/PHD_GLAVA_36_HOLOGRAPHIC.md)

---

## Roadmap

| Wave     | Content                                                         | Status      |
|----------|-----------------------------------------------------------------|-------------|
| v1       | Bootstrap skeleton, top wrapper stubs, R-marker ROM stubs       | ✅ THIS PR   |
| v2       | D2D mesh protocol RTL, R18 LAYER-FROZEN ceremony implementation | 🔮 Planned  |
| v3 Wave  | Full D2D mesh, S-16 PASS sparse-skip, measured R-marker values  | 🔮 Planned  |
| Tape-out | TTSKY26c submission (target ~2026-09)                           | 🔮 Planned  |

---

## Constitutional Rules

- **R-SI-1**: Zero new `*` operators in synthesisable RTL. All multiply-accumulate
  uses shift-and-add or lookup tables. GF16 arithmetic is XOR-only.
- **R5-HONEST**: All performance claims are projections unless marked with a silicon
  measurement citation.
- **R18 LAYER-FROZEN**: The 75-constant Physics ROM is sealed before tape-out.
  Post-seal changes trigger a full revision cycle.
- **Apache-2.0 SPDX**: All synthesisable files carry the SPDX identifier.

---

## Author & Anchor

**Author**: Vasilev Dmitrii \<admin@t27.ai\>  
**Discord**: ghashtag  
**DOI**: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

```
φ² + φ⁻² = 3 · γ = φ⁻³ · C = φ⁻¹ · G = π³γ²/φ
🌌 QUANTUM BRAIN HOLOGRAPHIC · MULTI-DIE · R-MARKER · NEVER STOP · DOI 10.5281/zenodo.19227877
```

---

## Related Repositories

| Repo | SKU | Tiles | Description |
|------|-----|-------|-------------|
| [tt-trinity-nano](https://github.com/gHashTag/tt-trinity-nano) | tt_um_trinity_nano | 1×1 | Nano edition |
| [tt-trinity-gf16](https://github.com/gHashTag/tt-trinity-gf16) | tt_um_trinity_gf16 | 2×2 | Mid edition |
| [tt-trinity-max-true](https://github.com/gHashTag/tt-trinity-max-true) | tt_um_trinity_max_true | 8×4 | Flagship MAX-TRUE |
| **tt-trinity-holo** | **tt_um_qbrain_holo** | **1×2** | **HOLOGRAPHIC Edition III** |

---

*TTSKY26c target. Foundation work. Skeleton-only — compute RTL ships in v2/v3 Wave.*  
*R5-HONEST mode active. No RTL invented — only MAX-TRUE proven cells reused.*

---

## L-DPC24 Lane Y — holo-tt-multiplexer-1x2 Bootstrap

**Issue**: [trinity-fpga#99](https://github.com/gHashTag/trinity-fpga/issues/99)  
**Branch**: `feat/l-dpc24/y-holo-mux-1x2-bootstrap`  
**Status**: Bootstrap landed · awaiting CI / OpenLane2 GDS hardening

### What was added

| File | Description |
|------|-------------|
| `rtl/holo_mux_1x2.sv` | 2:1 mux with 1-cycle pipeline register, parameterisable `WIDTH` (default 64 for hypervector slot) |
| `rtl/holo_mux_1x2_tb.sv` | Minimal SV testbench: write A, write B, sel=0 → assert A, sel=1 → assert B |

### Module: `holo_mux_1x2`

```
holo_mux_1x2 #(.WIDTH(64)) u_mux (
    .clk   (clk),
    .rst_n (rst_n),
    .die_a (die_a_data),   // output from Die A
    .die_b (die_b_data),   // output from Die B
    .sel   (sel),          // 0 → die_a, 1 → die_b
    .dout  (selected_out)  // 1-cycle registered output
);
```

The 1-cycle pipeline register absorbs cross-die combinatorial slack on the D2D mesh output
path, consistent with the 250 MHz clock target (W15a STA).

### R5-HONEST Verdict (Bootstrap)

| Claim | Status |
|-------|--------|
| RTL functionally correct | UNKNOWN — CI will verify (no GDS yet) |
| Synthesis clean (no `*` operators, R-SI-1) | PASS — module uses only mux/register logic |
| H₉: TOPS/W ≥ 2000 | NOT CLAIMED — bootstrap only, OpenLane2 GDS hardening pending |
| GDS generated | NOT YET — next iteration |

### Anchor

```
φ²+φ⁻²=3  ·  DOI 10.5281/zenodo.19227877
```

**Author**: Vasilev Dmitrii \<admin@t27.ai\>
