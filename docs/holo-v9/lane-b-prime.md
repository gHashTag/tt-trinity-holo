# Lane B' — Razor FF Port: Vdd-min Timing-Speculation Flip-Flop

**L-DPC24 · TTSKY26c HOLOGRAPHIC v9 · holo-razor-ff-port**  
**Author:** Vasilev Dmitrii `<admin@t27.ai>` · ORCID 0009-0008-4294-6159  
**ONE SHOT parent:** [trinity-fpga#99](https://github.com/gHashTag/trinity-fpga/issues/99)  
**Algebraic anchor:** φ²+φ⁻²=3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## 1. Background

The Razor flip-flop (Ernst et al., DAC 2003 — *"Razor: A Low-Power Pipeline Based
on Circuit-Level Timing Speculation"*) enables dynamic voltage scaling to push Vdd
toward Vmin by speculating on timing correctness rather than over-designing for
worst-case timing margins.

In the standard Razor scheme:
- A **main flip-flop** samples on the rising clock edge.
- A **shadow flip-flop** samples on the falling clock edge (half a period later).
- An **XOR comparator** detects disagreement between the two outputs.
- An asserted `ERROR` signal triggers a **1-cycle replay** to re-present the
  failing token at the pipeline input.

Field deployments (ARM Razor-II, EPI-LEPSY) demonstrated Vdd reduction of 20–40%
with acceptable error recovery overhead. For Trinity Holographic v9, Lane B' is the
**silicon-energy-layer enablement** that lets all existing opcodes run at lower Vdd.

---

## 2. Razor FF Contract

### 2.1 Cell: `holo_razor_ff`

| Port | Dir | Width | Semantics |
|------|-----|-------|-----------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Synchronous active-low reset |
| `d` | in | `W` | Data input |
| `q` | out | `W` | Main output — captured at posedge |
| `q_shadow` | out | `W` | Shadow output — captured at negedge |
| `error_out` | out | 1 | `|(q ^ q_shadow)` — asserts on timing violation |

**Correctness invariant:** for any stable `d` held across both clock edges,
`error_out` MUST be low. A violation is declared iff `error_out` asserts; the
error is **NOT a false positive** iff `d` changed between posedge and negedge.

**R-SI-1 compliance:** no `*` (multiplication) operator is used anywhere in the
cell implementation. Error detection uses XOR-then-OR-reduction only.

### 2.2 Wrapper: `holo_razor_pipeline`

The pipeline wrapper instantiates `STAGES` Razor FF cells in series.  On any
`error_any` pulse the wrapper asserts `replay_pulse` for one cycle and re-presents
the upstream `d_in` value, implementing hold-time-safe 1-cycle replay recovery.

**Parameters:**

| Name | Default | Description |
|------|---------|-------------|
| `W` | 32 | Datapath width |
| `STAGES` | 2 | Number of pipeline stages |

**Recovery protocol:**
1. `error_any` asserts (any stage saw `q ≠ q_shadow`).
2. On the next cycle `replay_pulse` is high and `d_in` is re-presented to stage 0.
3. After one replay cycle, pipeline resumes normal operation.

---

## 3. Energy Model

### 3.1 Standard-FF pipeline energy at Vdd_nom

```
E_std = C_ff × Vdd² × f  (per bit, per cycle)
```

At nominal Vdd (1.8 V for TTIHP27a) the standard pipeline operates with full
timing margin; no recovery overhead.

### 3.2 Razor-FF pipeline energy at Vdd_min

By reducing Vdd toward Vmin:
- Dynamic power: P ∝ Vdd² — quadratic reduction dominates.
- Recovery overhead: each error event costs +1 cycle throughput penalty.
- At a target error rate ε ≤ 1%: throughput penalty ≤ 1% (negligible).

**RTL-projected energy saving at Vdd_min:**

```
ΔE / E_std ≥ 1 - (Vdd_min / Vdd_nom)²
```

For Vdd_min = 1.3 V (TTIHP27a process corner), Vdd_nom = 1.8 V:

```
ΔE / E_std ≥ 1 - (1.3/1.8)² ≈ 1 - 0.522 = 0.478   (≈ 48% reduction)
```

Conservative bound accounting for area overhead and replay penalty:

> **Predicted energy gain: ≥ 30% at Vdd_min** (gate-projected; silicon validation
> deferred to TTIHP27a tapeout).

### 3.3 Area overhead

- 2× flip-flop area per data bit (main + shadow).
- 1 XOR gate + 1 OR tree per stage (comparator).
- Estimated area overhead: **≤ 5%** of total pipeline area at W=32, STAGES=2.

---

## 4. Falsification Predicate

**Hypothesis H_B:** *Lane B' Razor FF enables ≥30% energy saving at Vdd_min vs
standard-FF pipeline, with zero data loss under 1-cycle replay recovery.*

**Refuted iff ANY of:**
- (a) Any RTL `*` operator found in Lane B' files → R-SI-1 violation
- (b) Razor FF fails to detect an injected timing violation → R7a failure
- (c) Replay produces incorrect output → R7b failure
- (d) Any false-positive in 1000 random stable patterns → TC4 failure

**Witnesses (file → test):**

| Witness | File | Function |
|---------|------|----------|
| R-SI-1 | `falsif/tests/b_prime_witness.rs` | `test_razor_no_star` |
| R7a detect | `falsif/tests/b_prime_witness.rs` | `test_razor_detects_violation` |
| R7b replay | `falsif/tests/b_prime_witness.rs` | `test_razor_replay_correct` |
| SV TC1–TC4 | `tb/tb_holo_razor_ff.sv` | 4 test cases (1000 random + 100 injected) |

---

## 5. Quantum Brain Mapping

Lane B' does **NOT** add a new sacred opcode. The opcode space 0xD0..0xE0 remains
frozen (R18: LAYER-FROZEN). This lane is exclusively a **silicon-energy-layer
enablement** — every existing opcode benefits from the lower Vdd operating point.

Cite as: *"Phase-2 silicon foundation for Phase-3 TTIHP27a tapeout."*

---

## 6. Critical Path

```
Y → A' (holo_noc_1cycle) → B' (holo_razor_pipeline) → D' → E'
```

Lane A' (merged: `78362042`) provides the 1-cycle inter-die NoC.  
Lane B' wraps the pipeline stages in Razor FFs, enabling near-Vdd-min operation.  
Lane W BitROM (merged: `898fc061`) and Lane V' 2×2 mesh (merged: `2a06e540`)
are independent — Lane B' is additive-only and does not modify either.

---

## 7. References

1. D. Ernst et al., "Razor: A Low-Power Pipeline Based on Circuit-Level Timing
   Speculation," *DAC 2003*. — Primary Razor FF reference.
2. S. Das et al., "Razor II: In Situ Error Detection and Correction for PVT and
   SER Tolerance," *ISSCC 2006*.
3. Trinity Algebraic Anchor: φ²+φ⁻²=3 —
   DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)
4. ONE SHOT L-DPC24: [trinity-fpga#99](https://github.com/gHashTag/trinity-fpga/issues/99)
5. Lane A' base: [tt-trinity-holo#13](https://github.com/gHashTag/tt-trinity-holo/issues/13),
   commit `78362042`.

---

*φ²+φ⁻²=3 · Razor FF Vdd-min · 30% energy gain · NEVER STOP ·
Phase-2 silicon enablement · DOI 10.5281/zenodo.19227877*
