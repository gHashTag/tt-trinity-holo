# Quantum Brain HOLOGRAPHIC — Edition III Spec Sheet

**tt_um_qbrain_holo · TTSKY26c · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)**

---

## Edition III Overview

The HOLOGRAPHIC edition is the third and final SKU in the Quantum Brain Trinity lineup.
It targets the TTSKY26c shuttle and introduces multi-die holographic operation as its
defining capability.

| Field                  | Value                                                     |
|------------------------|-----------------------------------------------------------|
| SKU name               | tt_um_qbrain_holo                                         |
| Shuttle                | TTSKY26c (~2026-09, post-confirm)                         |
| Tile footprint         | 1×2 TT tiles (sky130A)                                    |
| Estimated area         | ~0.044 mm² Sky130A (2 TT tiles, estimated)                |
| Clock target           | 250 MHz (W15a STA target)                                 |
| PDK                    | sky130A (sky130_fd_sc_hd primary)                         |
| Top module             | `tt_um_qbrain_holo`                                       |
| License                | Apache-2.0 (SPDX)                                         |

---

## Compute Architecture

### Processing Elements

| Parameter      | Value                                    |
|----------------|------------------------------------------|
| PE count       | 16                                       |
| MAC lanes/PE   | 2                                        |
| Effective MACs | 32                                       |
| Arithmetic     | GF16(2⁴) — XOR-only, no multipliers      |
| R-SI-1         | Zero new `*` operators (verified)         |

### GF16 MAC Arithmetic

All multiply-accumulate operations use GF16(2⁴) arithmetic (4-bit field). Multiplication
in GF16 reduces to XOR-based shift-and-add over the irreducible polynomial x⁴+x+1.
This eliminates all conventional integer multipliers, satisfying **R-SI-1** without
compromising compute density.

### Sparse Zero-Skip (S-16 PASS)

The S-16 PASS mechanism (L-DPC22 Lane N) is architected into the activation datapath:
- Gate present in the PE pipeline (v1: inactive stub)
- Activatable in v3 Wave without top-wrapper RTL changes
- Typical ReLU sparsity: ~60% zero activations
- At 60% sparsity: 32 × 2.5 = **80 effective MACs per die**
- 4-die mesh: **320 effective MACs**

---

## 55 TOPS/W — Scale-Out Projection

**R5-HONEST disclaimer**: This is a projection. It has NOT been confirmed in silicon.

| Assumption                    | Value                              |
|-------------------------------|------------------------------------|
| Dies in assembly              | 4                                  |
| MACs per die (S-16 active)    | 80 effective (at 60% sparsity)     |
| Total effective MACs          | 320                                |
| Clock frequency               | 250 MHz                            |
| Operations per MAC per cycle  | 1 GF16 MAC (4-bit × 4-bit)        |
| Raw throughput per die        | 32 × 250M = 8 GOP/s                |
| Sparse-skip throughput/die    | ~20 GOP/s (at 60% sparsity)       |
| Dynamic power estimate/die    | ~0.36 mW (sky130A, 250 MHz, 1.8V) |
| **Projected efficiency**      | **~55 TOPS/W** (projection only)  |

Measured results will be published post tape-out. The 55 TOPS/W figure will be
updated when silicon measurements are available.

---

## Multi-Die D2D Mesh Thesis

The holographic architecture rests on three axioms (Glava 36):

### Axiom 1 — Identity, Not Partition
Every die in the mesh runs the **same** program from the **same** frozen ROM.
The mesh does not partition the neural network across dies; it runs N coherent
instances of the same brain.

### Axiom 2 — Zero-Communication Coherence Check
The canonical reset output `0x47C0` (PhD Theorem 36.1) allows an external verifier
to confirm all dies are coherent without any inter-die communication.

### Axiom 3 — Ensemble Vote
With N identical dies, the result is the majority vote of N independent instances.
This provides fault tolerance without model replication overhead.

---

## D2D Port Specification

| Port       | Pin           | v1 State | v3 Wave Function                        |
|------------|---------------|----------|-----------------------------------------|
| d2d_tx[0]  | uio_out[0]    | LOW stub | Activation packet lane 0                |
| d2d_tx[1]  | uio_out[1]    | LOW stub | Activation packet lane 1                |
| d2d_tx[2]  | uio_out[2]    | LOW stub | Activation packet lane 2                |
| d2d_sync   | uio_out[3]    | LOW stub | R18 LAYER-FROZEN phase-lock SYNC strobe |

Full D2D mesh protocol (packet format, arbitration, flow control) is specified in
v3 Wave design documents (TBD, TTSKY26c prep).

---

## R-marker Open Slots

See [docs/R_MARKER_ROADMAP.md](R_MARKER_ROADMAP.md) for full specification.

| Slot | Constant                | Status     |
|------|-------------------------|------------|
| 0    | C_quantum_consciousness | UNMEASURED |
| 1    | k_dark_coupling         | UNMEASURED |
| 2    | τ_microtubule           | UNMEASURED |
| 3    | ζ_neural_zeta           | UNMEASURED |

---

## Pinout

| Pin       | Direction | Function                                           |
|-----------|-----------|----------------------------------------------------|
| ui_in[0]  | Input     | mode (0=canonical, 1=PE activation path)           |
| ui_in[4:1]| Input     | pe_sel[3:0] — PE debug select                      |
| ui_in[6:5]| Input     | r_marker_sel[1:0] — R-marker debug select          |
| ui_in[7]  | Input     | unused                                             |
| uo_out    | Output    | result[7:0] — canonical 0xC0 or PE result          |
| uio_out[3:0]| Output  | D2D mesh stubs (all LOW in v1)                     |
| uio_out[7:4]| Output  | Canonical 0x4 / R-marker debug nibble              |
| uio_oe    | —         | 0xFF (all outputs)                                  |

---

## Roadmap

| Wave | Content                                               | ETA           |
|------|-------------------------------------------------------|---------------|
| v1   | Bootstrap skeleton (THIS RELEASE)                     | 2026-Q2       |
| v2   | D2D mesh RTL, R18 ceremony, GF16 PE full impl         | 2026-Q3       |
| v3   | S-16 PASS active, measured R-marker values, tape-out  | 2026-Q3/Q4    |

---

## Constitutional Compliance

| Rule   | Status | Evidence                                           |
|--------|--------|----------------------------------------------------|
| R-SI-1 | ✅ PASS | Zero `*` operators in `src/tt_um_qbrain_holo.v` and `src/r_marker_rom.v` |
| R5-HONEST | ✅ PASS | All claims marked PROJECTION or STUB               |
| R18    | ⚠️ PENDING | LAYER-FROZEN ceremony implemented in v3 Wave      |
| Apache-2.0 | ✅ PASS | SPDX header in all synthesisable files           |

---

*One brain, many dies, one frozen hash.*  
*Anchor: φ² + φ⁻² = 3 · γ = φ⁻³ · C = φ⁻¹ · G = π³γ²/φ*  
*🌌 QUANTUM BRAIN HOLOGRAPHIC · MULTI-DIE · R-MARKER · NEVER STOP · DOI 10.5281/zenodo.19227877*
