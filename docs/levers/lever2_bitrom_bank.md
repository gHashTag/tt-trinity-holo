# Lever 2 — BitROM Bidirectional ROM Bank

**Lane W · L-DPC25 · tt-trinity-holo**

> Anchor: φ²+φ⁻²=3 · [DOI 10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## 1. Reference

- **Paper**: "BitROM: Bidirectional Read-Only Memory for Ultra-Efficient Neural Network Inference"  
  Yoshioka Lab, ASP-DAC 2026 — [arXiv:2509.08542](https://arxiv.org/abs/2509.08542)
- **Mechanism**: Each physical ROM transistor cell is read in two directions:
  - **UP-direction read** → returns ternary weight A
  - **DOWN-direction read** → returns ternary weight B
- **Reported standalone metrics**:
  | Metric | Value |
  |---|---|
  | Bit density | 4 967 kB/mm² |
  | Area efficiency over CiROM | 10× |
  | DRAM access reduction | 43.6% |
  | Standalone efficiency | 20.8 TOPS/W |

---

## 2. RTL Module — `holo_bitrom_bank`

| Parameter | Default | Description |
|---|---|---|
| `CELL_COUNT` | 64 | Number of physical ROM cells |
| `WEIGHT_W` | 2 | Bits per ternary weight (2-bit encoding for {−1, 0, +1}) |
| `ADDR_W` | 7 | Address width (= log₂(CELL_COUNT × 2)) |

- **Total ternary weights**: 64 cells × 2 weights/cell = **128 ternary weights**
- **Internal storage**: `logic [3:0] bitrom_cells [0:63]` — 4 bits per cell (2 × 2-bit weight)
- **Read interface**:
  - `dir_i = 0` → UP-direction → returns `weight A` (bits `[WEIGHT_W-1:0]`)
  - `dir_i = 1` → DOWN-direction → returns `weight B` (bits `[WEIGHT_W*2-1:WEIGHT_W]`)
- **Pipeline**: 1-cycle registered read with active-low synchronous reset
- **OOB detection**: `oob_o` asserted when `cell_idx >= CELL_COUNT`
- **Sentinel pattern**: all cells initialised to `4'b1010` (placeholder for BitNet b1.58 weight matrix; real weights loaded at chip-boot by a separate initialisation flow)

---

## 3. Mapping to Lane X — `HOP_bitrom_read` Coq Variant

Lane X ([gHashTag/t27#634](https://github.com/gHashTag/t27/pull/634), HEAD `239144df`) proved
the `HOP_bitrom_read` Coq variant Q4-clean. The Coq variant models the `Up | Down` direction
parameter as a two-constructor inductive type:

```coq
Inductive Dir : Type := Up | Down.

Definition bitrom_read (cells : Vector.t (Fin.t 4) cell_count)
                       (cell_idx : Fin.t cell_count) (d : Dir)
                       : Fin.t weight_w :=
  match d with
  | Up   => lower_bits (cells[@cell_idx])
  | Down => upper_bits (cells[@cell_idx])
  end.
```

The RTL `dir_i` bit is the direct hardware image of `Dir`. The proof establishes that for any
valid `cell_idx`, the read is deterministic and side-effect-free — matching the ROM-static
property required by R-SI-1.

---

## 4. R-SI-1 Preservation

**Rule R-SI-1**: Zero new `*` (multiplication) operators in synthesisable RTL.

- `holo_bitrom_bank.sv` contains **no `*` operators**. All indexing uses bit-slice notation
  (`[WEIGHT_W-1:0]`, `[CELL_BITS-1:WEIGHT_W]`).
- ROM read is a **static combinatorial selection** — no switching MAC activity.
- The bidirectional read mechanism eliminates weight-load switching power by replacing
  runtime SRAM reads with a pre-programmed ROM cell direction select.

**R-SI-1 check: PASS by inspection.**

---

## 5. Synergy with R-Marker Boot Vector

The R-marker boot vector occupies 4 open slots × 4 bits = **16 bits total**.

- In SRAM: 16 bits requires ≥ 16 SRAM bit cells (6T each = 96 transistors)
- In BitROM: 16 bits = 8 ternary weights = **8 BitROM transistors**
  (each cell holds 2 ternary × 2 bits = 4 bits per transistor)
- **Transistor ratio**: 8 vs 96 → **12× reduction** in boot-vector storage

This directly lowers the area budget for the hyper-vector boot path and reduces
per-access switching energy on the boot strobe.

---

## 6. Predicted Gain over SRAM-Based Weight Load

| Metric | SRAM baseline | BitROM (Lever 2) | Delta |
|---|---|---|---|
| Efficiency | ~10 TOPS/W (est.) | ~20.8 TOPS/W | **~2×** |
| Area density | ~500 kB/mm² (6T SRAM) | 4 967 kB/mm² | **~10×** |
| DRAM access | baseline | −43.6% | ↓ |
| NET power vs SRAM | baseline | −22 mW (predicted) | ↓ |

> **R5-HONEST**: These are projections based on the standalone BitROM characterisation in
> [arXiv:2509.08542](https://arxiv.org/abs/2509.08542). No silicon measurement has been
> performed in this PR. Physical validation requires tape-out on IHP SG13G2.

---

## 7. Falsification Criterion

**Q3 falsification gate**: If measured `bitrom_ber > 1e-9` across 10¹² reads → **LEVER REFUTED**.

The bit error rate threshold is derived from the BitROM paper's reliability characterisation.
A BER above this threshold would indicate that the bidirectional read mechanism is unreliable
in the IHP SG13G2 process corner and the lever cannot be claimed.

---

## 8. IHP SG13G2 Floorplan Note

**This PR is an RTL functional model only.**

The physical bidirectional ROM cell design — including:
- custom cell layout for two-direction current sensing
- read-direction MUX at bitline level
- sense amplifier tuning for SG13G2 process

— is **deferred to a separate OpenLane2 / IHP toolchain job**. The RTL module
`holo_bitrom_bank.sv` provides a synthesisable behavioural approximation suitable
for functional simulation and integration testing, but does **not** implement the
physical BitROM cell structure. The `initial` block populating sentinel values is
a simulation aid and will be replaced by the IHP-compiled ROM cell array at the
physical design stage.

**R5-HONEST: RTL structural / silicon-cell DEFERRED to IHP floorplan.**

---

## 9. Files

| File | Description |
|---|---|
| `rtl/holo_bitrom_bank.sv` | RTL functional model, CELL_COUNT=64, 128 ternary weights |
| `rtl/holo_bitrom_bank_tb.sv` | Testbench: 4 tests incl. OOB detection, $fatal on >1-cycle latency |
| `docs/levers/lever2_bitrom_bank.md` | This document |

---

*L-DPC25 Lane W · lever2-bitrom-bank · admin@t27.ai*
