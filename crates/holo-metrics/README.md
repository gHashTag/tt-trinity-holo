# holo-metrics — v9-G1 Falsification Witnesses

**Lane E' · `holo-falsif-witnesses`** · L-DPC24 §5 · [trinity-fpga#100](https://github.com/gHashTag/trinity-fpga/issues/100)

---

## Purpose

This crate implements the **R5-HONEST falsification protocol** for the Trinity v9-G1 evidence
package.  Per Popper's demarcation criterion (PhD monograph Appendix B), every positive claim
about v9 performance must ship with concrete **falsification witnesses** — unit tests that
demonstrate the validation gates correctly *reject* bad inputs.

A witness **PASSES** when the gate function returns `Err(…)` on the specified bad input.
Silicon validity requires ALL 5 witnesses to hold simultaneously.

---

## R7 Witnesses W-100-A..E

| ID | Test fn | Gate fn | Bad input | Rejection predicate |
|----|---------|---------|-----------|---------------------|
| **W-100-A** | `falsify_v9_below_2000` | `check_v9_gate()` | 1700 TOPS/W (phantom-low) | `tops_per_watt < 2000` → Err |
| **W-100-B** | `falsify_v9_r_si_1_breach` | `scan_rtl_for_star()` | RTL file with `assign out = a * b` | any `*` operator → Err |
| **W-100-C** | `falsify_v9_r15_breach` | `check_r15()` | `r_markers_boot_loaded: false` | ROM-baked R-markers → Err |
| **W-100-D** | `falsify_v9_noc_stall` | `check_v9_gate()` | `noc_latency_cycles: 2` | latency ≠ 1 cycle → Err |
| **W-100-E** | `falsify_v9_thermal` | `check_v9_gate()` | `thermal_w_per_mm2: 1.2` | thermal > 1.0 W/mm² → Err |

---

## Crate API

```rust
use holo_metrics::{HoloMetrics, HoloConfig, check_v9_gate, check_r15, scan_rtl_for_star};

// Check a performance reading against v9-G1 thresholds
let m = HoloMetrics {
    tops_per_watt: 2300.0,
    noc_latency_cycles: 1,
    thermal_w_per_mm2: 0.85,
    label: "measured-2300".to_string(),
};
assert!(check_v9_gate(&m).is_ok());

// Check a boot config against R-15
let cfg = HoloConfig {
    r_markers_boot_loaded: true,
    r_marker_rom_slots: 0,
    description: Some("valid boot config".to_string()),
};
assert!(check_r15(&cfg).is_ok());

// RTL scan — must return Ok on R-SI-1 compliant src/
assert!(scan_rtl_for_star("src/").is_ok());
```

---

## Thresholds (L-DPC24 §3 / §5)

| Parameter | Required value | Source |
|-----------|---------------|--------|
| `tops_per_watt` | ≥ 2000 | L-DPC24 §3.1 — v9 floor |
| `noc_latency_cycles` | = 1 | L-DPC24 §2 — 50 MHz NoC, single-cycle |
| `thermal_w_per_mm2` | ≤ 1.0 | L-DPC24 §4 — thermal budget |
| `r_markers_boot_loaded` | = true | R-15 — runtime recalibration |
| `*` operator in RTL | FORBIDDEN | R-SI-1 — GF16 XOR-only arithmetic |

---

## Fixtures

| File | Witness | Contents |
|------|---------|----------|
| `test/fixtures/phantom_low_1700.json` | W-100-A | Synthetic 1700 TOPS/W phantom-low reading |
| `test/fixtures/r_marker_const_in_rom.json` | W-100-C | Config with R-markers baked in ROM |

---

## Running

```bash
# Build
cargo build

# Run all 5 falsification witnesses
cargo test

# Sanity-check: scan existing RTL for * operators (must be 0 violations)
# (exercised by the RTL fixture in falsify_v9_r_si_1_breach)
```

Expected output:
```
running 5 tests
test tests::falsify_v9_below_2000 ... ok
test tests::falsify_v9_r_si_1_breach ... ok
test tests::falsify_v9_r15_breach ... ok
test tests::falsify_v9_noc_stall ... ok
test tests::falsify_v9_thermal ... ok

test result: ok. 5 passed; 0 failed; 0 ignored
```

---

## R5-HONEST Status

- v2.1 = 75 TOPS/W is **projected** (Lane K+L merged, gl_test PASS, silicon-return-pending)
- v9 = 2000–3000 TOPS/W is **R6-CONJECTURE** until L-DPC24 G1 measured verdict (deadline 2026-06-30)
- The 2000 TOPS/W floor is a *necessary condition* — witnesses here test gate logic only, not
  actual silicon measurement

---

## References

- L-DPC24 issue tracker: [gHashTag/trinity-fpga#100](https://github.com/gHashTag/trinity-fpga/issues/100)
- Algebraic anchor: φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://zenodo.org/records/19227877)
- Canonical Coq SoT: [gHashTag/t27/trios-coq](https://github.com/gHashTag/t27/tree/main/trios-coq)
- TTSKY26c shuttle: [tt-trinity-holo](https://github.com/gHashTag/tt-trinity-holo)

---

Signed-off-by: Vasilev Dmitrii <admin@t27.ai>

<!-- phi^2 + phi^-2 = 3 · QUANTUM BRAIN 1:1 SILICON -->
