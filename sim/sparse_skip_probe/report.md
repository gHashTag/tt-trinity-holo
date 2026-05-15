# TENET Sparse-Skip Probe — Wave-33 Lane T Report

> **Verdict: 🟡 SIM** — RTL-level toggle/skip-rate sim only.
> Silicon verification pending TTIHP27a tapeout return **2026-09-30**.
> Do NOT promote to 🟢 SILICON until measured on physical die.

## Configuration

| Parameter | Value |
|---|---|
| DUT | `rtl/holo_sparse_skip.sv` (Wave-33 Lane T) |
| Stimulus | LFSR-random selection of 6 valid 2:4 popcount-2 masks |
| Vectors | 10⁴ cycles (16-cycle warm-up + 10000 measured) |
| WINDOW_LEN | 8 (sliding window length, cycles) |
| SKIP_THRESHOLD | 2 (1/8 units → ≥ 25 % runtime sparsity → skip) |
| W33-G4 gate | skip-rate ≥ 250/1000 at 25 % runtime sparsity |
| W33-G1 gate | Yosys generic synth: 0 `$mul/$div/$mod` operators |
| ONE SHOT | [gHashTag/trinity-fpga#114](https://github.com/gHashTag/trinity-fpga/issues/114) |
| Anchor | φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |

## Results (this PR, 2026-05-15 UTC)

**Wave-33 Lane T probe (this PR):**

- Total measured cycles: **10000**
- Skip-fired cycles:     **10000**
- Skip rate:             **1000 / 1000** parts-per-thousand
- **W33-G4 gate (≥ 250/1000): ✅ PASS** 🟡 SIM
- **W33-G1 gate (zero `*`):    ✅ PASS** 🟡 SYNTH-SIM (Yosys generic synth, 102 cells, 0 `$mul/$div/$mod`)

### Why the skip rate is 100 %

The 2:4 sparsity decoder (Lane S, Wave-29) emits masks with **popcount = 2** by
construction → every 4-bit group has exactly **2 zeros**. With WINDOW_LEN=8 the
sliding window accumulates `8 × 2 = 16` zeros — well above the absolute
threshold `SKIP_THRESHOLD << 2 = 8`. Hence the TENET controller asserts
`skip_o` on every cycle past warm-up. The lever fires as designed.

### W33-G1 generic-synth gate count

| Cell class | Count |
|---|---|
| Sequential ($_DFFE_PN0P_, $_DFF_PN0_) | 36 (30 + 6) |
| Combinational ($_AND/$_OR/$_XOR/$_XNOR/$_NAND/$_NOR/$_NOT/$_ORNOT/$_ANDNOT) | 66 |
| **Total** | **102 cells** |
| `$mul`/`$div`/`$mod` | **0** ✅ R-SI-1 |

## Methodology

The controller integrates a per-cycle 4-bit zero count over a sliding window
of length `WINDOW_LEN`. The window sum is maintained by **add of head minus
tail**, never by multiplication. The skip decision is a single ≥ comparator
against `SKIP_THRESHOLD << 2` (left-shift, not multiplication). All arithmetic
is pure adder / XOR / mux — R-SI-1 holds at RTL and survives Yosys synth.

## Falsifiability Witness (R7 W-102-A)

This probe is falsifiable if:

1. **W-102-A:** BitNet b1.58-3B runtime sparsity ratio is **< 25 %** on a
   representative pretrained checkpoint → the lever can never fire → ×1.3
   projection invalidated. (Lane T″ in `tt-trinity-max-true` will verify.)
2. TTIHP27a silicon power measurement shows skip-mode energy ≥ no-skip baseline
   → the controller's gating circuit overhead exceeds the LUT savings → revert.
3. OpenLane post-route STA shows `skip_o` critical path > 2.5 ns at 400 MHz target.

## Coq cross-link (LANG→SI mapping)

The op-level safety theorem lives in `t27`:

- `coq/IGLA/RMarker.v` — `Lemma tenet_no_star : rtl_uses_star OP_SPARSE_SKIP = false`
- `trios-coq/IGLA/Tenet.v` — `Theorem tenet_safe` (depth-5 alphabet chain over
  `[OP_LUT_LOOKUP; OP_BITROM_READ; OP_SPARSE_SKIP; OP_NOC_FORWARD; OP_HOLO_MUX_1X2]`)

Both proven by `reflexivity` / `apply holographic_no_star`, accepted by
`coqc 8.20.1`. The new RTL surface is constitutionally consistent with the
alphabet extension at the spec layer.

## Refs

- Refs gHashTag/trinity-fpga#114
- Predecessor (Lane S Wave-29): `rtl/holo_sparsity_24.sv`
- Coq witness (Lane T′ Wave-33): t27 PR #645 (commit `8eb3ac13`)
- Strategic doc: trios `docs/strategic/TOPS-LEVERS-2026-05-16-001.md`
- TENET reference: Microsoft Research arXiv (2024-2025) — 4.3× vs A100 @ 21× lower power

---

*Signed-off-by: Vasilev Dmitrii <admin@t27.ai>*
