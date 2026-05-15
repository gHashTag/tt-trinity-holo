# R-marker Roadmap — Falsifiable Physics Constants

**Quantum Brain HOLOGRAPHIC · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)**

---

## Philosophy (Popper Appendix B)

The R-marker architecture applies Popperian falsifiability to silicon design.
Each R-marker slot is an **open prediction**: the ROM currently holds a placeholder value (zero),
and the project commits to:

1. Measuring the corresponding physics constant through experiment or observation.
2. Writing the measured value into the ROM slot as a fixed-point encoding.
3. Taping out the updated silicon.

**Critical clause**: If the measured value differs from the previously programmed ROM value,
a **silicon revision is triggered** — the old silicon is retroactively falsified, and a
revised tape-out is required.

This follows Popper's demarcation criterion (Appendix B, PhD monograph):
> A scientific claim must be falsifiable. A silicon ROM that cannot be revised is not science;
> it is faith. The R-marker protocol ensures every constant is revisable.

---

## Slot Definitions

### Slot 0 — C_quantum_consciousness

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Symbol        | C_quantum_consciousness                            |
| Description   | Quantum coherence time constant in bio-neural tissue |
| Physical basis | Quantum Brain model (Glava 28, PhD monograph)     |
| Units         | Dimensionless (normalised to Planck time ×10⁻⁴⁴ s) |
| Fixed-point   | Q1.15 (1 sign bit, 15 fraction bits)               |
| Current value | `0x0000` — **UNMEASURED**                          |
| Status        | Open slot. TODO: revise when measured.             |
| Measurement source | Bio-neural coherence experiments (TBD)        |
| Revision trigger | Measurement deviates from ROM value by >1 LSB  |

---

### Slot 1 — k_dark_coupling

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Symbol        | k_dark_coupling                                    |
| Description   | Dark-sector coupling constant (cosmological scale) |
| Physical basis | Holographic extension (Glava 36, PhD monograph)   |
| Units         | Dimensionless (normalised to G_N gravitational coupling) |
| Fixed-point   | Q2.14 (2 integer bits, 14 fraction bits)           |
| Current value | `0x0000` — **UNMEASURED**                          |
| Status        | Open slot. TODO: revise when measured.             |
| Measurement source | Cosmological observation / dark matter direct detection (TBD) |
| Revision trigger | Measurement deviates from ROM value by >1 LSB  |

---

### Slot 2 — τ_microtubule

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Symbol        | τ_microtubule                                      |
| Description   | Microtubule decoherence time (Penrose-Hameroff)    |
| Physical basis | Neural quantum coherence sub-model (Glava 31)     |
| Units         | Dimensionless (normalised to nanosecond scale)     |
| Fixed-point   | Q0.16 (pure fraction)                              |
| Current value | `0x0000` — **UNMEASURED**                          |
| Status        | Open slot. TODO: revise when measured.             |
| Measurement source | Penrose-Hameroff experiment (in vitro microtubule coherence) |
| Revision trigger | Measurement deviates from ROM value by >1 LSB  |

---

### Slot 3 — ζ_neural_zeta

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| Symbol        | ζ_neural_zeta                                      |
| Description   | Neural zeta function zero (spectral graph theory)  |
| Physical basis | Spectral neural model (Glava 34, PhD monograph)   |
| Units         | Dimensionless (Q2.14 fixed point)                  |
| Fixed-point   | Q2.14 (2 integer bits, 14 fraction bits)           |
| Current value | `0x0000` — **UNMEASURED**                          |
| Status        | Open slot. TODO: revise when measured.             |
| Measurement source | Spectral graph analysis of cortical connectivity data (TBD) |
| Revision trigger | Measurement deviates from ROM value by >1 LSB  |

---

## Summary Table

| Slot | Constant                | Status     | Measurement Method          |
|------|-------------------------|------------|-----------------------------|
| 0    | C_quantum_consciousness | UNMEASURED | Bio-neural coherence exp.   |
| 1    | k_dark_coupling         | UNMEASURED | Cosmological observation     |
| 2    | τ_microtubule           | UNMEASURED | Penrose-Hameroff in vitro    |
| 3    | ζ_neural_zeta           | UNMEASURED | Spectral graph (cortical)    |

---

## Revision Protocol

When a constant is measured:
1. Convert measurement to the slot's fixed-point format.
2. Update `src/r_marker_rom.v`: replace `16'h0000` with measured value.
3. Update `sim/tb_r_marker.v`: replace `0x0000` assertion with measured value.
4. Tag the commit as `r-marker/slot-N-measured` with full measurement citation.
5. Trigger R18 LAYER-FROZEN ceremony to propagate updated ROM across all dies.
6. If prior silicon exists with `0x0000` in that slot: file a **silicon revision request**.

---

## R5-HONEST Statement

All four slots are currently zero-filled. This is not a fabrication error — it is an
explicit statement that these constants have not yet been measured. The placeholder values
are the most honest encoding of current ignorance (R5-HONEST protocol).

---

*Anchor: φ² + φ⁻² = 3*  
*DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)*
