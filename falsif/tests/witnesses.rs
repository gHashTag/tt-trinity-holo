//! Falsification witnesses for H₉ — L-DPC24 Lane E'
//!
//! Each predicate is tested on both a **pass** path (invariant holds) and a
//! **fail** path (invariant is violated), satisfying the Bonferroni-corrected
//! significance level α_corrected = 0.002 = 0.01 / 5.
//!
//! One-shot issue: <https://github.com/gHashTag/trinity-fpga/issues/99>
//! Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877

use holo_falsif::{
    check_p1_below_2000, check_p2_r_si_1_breach, check_p3_r15_breach, check_p4_noc_stall,
    check_p5_thermal, FalsifError,
};
use sha2::{Digest, Sha256};

// ─────────────────────────────────────────────────────────────────────────────
// Helper: compute SHA-256 of a u64 (little-endian bytes)
// ─────────────────────────────────────────────────────────────────────────────

fn sha256_u64(v: u64) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(v.to_le_bytes());
    h.finalize().into()
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: compute SHA-256 over a 75-element u64 array
// ─────────────────────────────────────────────────────────────────────────────

fn sha256_rom75(rom: &[u64; 75]) -> [u8; 32] {
    let mut h = Sha256::new();
    for cell in rom.iter() {
        h.update(cell.to_le_bytes());
    }
    h.finalize().into()
}

// ─────────────────────────────────────────────────────────────────────────────
// P1 — below_2000
// ─────────────────────────────────────────────────────────────────────────────

/// P1 PASS: measurement is exactly at threshold (2000.0) → H₉ holds.
#[test]
fn p1_pass_at_threshold() {
    assert_eq!(check_p1_below_2000(2000.0), Ok(()));
}

/// P1 PASS: measurement well above threshold.
#[test]
fn p1_pass_above_threshold() {
    assert_eq!(check_p1_below_2000(3500.0), Ok(()));
}

/// P1 FAIL: measurement strictly below 2000 → REJECT H₉.
#[test]
fn p1_fail_below_threshold() {
    let result = check_p1_below_2000(1999.99);
    assert!(matches!(
        result,
        Err(FalsifError::BelowThreshold {
            measured,
            threshold: 2000.0
        }) if (measured - 1999.99_f64).abs() < 1e-9
    ));
}

/// P1 FAIL: measurement is zero.
#[test]
fn p1_fail_zero() {
    assert!(matches!(
        check_p1_below_2000(0.0),
        Err(FalsifError::BelowThreshold { .. })
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// P2 — R_SI_1_breach
// ─────────────────────────────────────────────────────────────────────────────

/// P2 PASS: r_marker_value hashes to the frozen reference.
#[test]
fn p2_pass_hash_matches() {
    let marker: u64 = 0xDEAD_BEEF_CAFE_1234;
    let frozen = sha256_u64(marker);
    assert_eq!(check_p2_r_si_1_breach(marker, frozen), Ok(()));
}

/// P2 FAIL: r_marker_value has been mutated → NULL & VOID.
#[test]
fn p2_fail_marker_mutated() {
    let original: u64 = 0xDEAD_BEEF_CAFE_1234;
    let frozen = sha256_u64(original);
    let mutated: u64 = original ^ 1; // single-bit mutation
    let result = check_p2_r_si_1_breach(mutated, frozen);
    assert!(matches!(result, Err(FalsifError::RMarkerMutation { .. })));
}

// ─────────────────────────────────────────────────────────────────────────────
// P3 — R15_breach
// ─────────────────────────────────────────────────────────────────────────────

/// P3 PASS: sacred ROM is intact, hash matches frozen reference.
#[test]
fn p3_pass_rom_intact() {
    let rom: [u64; 75] = core::array::from_fn(|i| i as u64 * 0x0102_0304_0506_0708);
    let frozen = sha256_rom75(&rom);
    assert_eq!(check_p3_r15_breach(&rom, frozen), Ok(()));
}

/// P3 FAIL: one cell of the sacred ROM has drifted → NULL & VOID.
#[test]
fn p3_fail_rom_drift() {
    let rom: [u64; 75] = core::array::from_fn(|i| i as u64 * 0x0102_0304_0506_0708);
    let frozen = sha256_rom75(&rom);
    let mut drifted = rom;
    drifted[37] ^= 0xFFFF_FFFF_FFFF_FFFF; // corrupt cell 37
    let result = check_p3_r15_breach(&drifted, frozen);
    assert!(matches!(result, Err(FalsifError::SacredRomDrift { .. })));
}

// ─────────────────────────────────────────────────────────────────────────────
// P4 — noc_stall
// ─────────────────────────────────────────────────────────────────────────────

/// P4 PASS: zero stall cycles.
#[test]
fn p4_pass_no_stall() {
    assert_eq!(check_p4_noc_stall(0), Ok(()));
}

/// P4 PASS: exactly 1 stall cycle (boundary, still acceptable).
#[test]
fn p4_pass_one_stall() {
    assert_eq!(check_p4_noc_stall(1), Ok(()));
}

/// P4 FAIL: 2 stall cycles → re-arch required.
#[test]
fn p4_fail_two_stalls() {
    let result = check_p4_noc_stall(2);
    assert!(matches!(
        result,
        Err(FalsifError::NocStall { stall_cycles: 2 })
    ));
}

/// P4 FAIL: large stall count.
#[test]
fn p4_fail_large_stall() {
    assert!(matches!(
        check_p4_noc_stall(1000),
        Err(FalsifError::NocStall { stall_cycles: 1000 })
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// P5 — thermal
// ─────────────────────────────────────────────────────────────────────────────

/// P5 PASS: hotspot exactly at limit (1.0 W/mm²).
#[test]
fn p5_pass_at_limit() {
    assert_eq!(check_p5_thermal(1.0), Ok(()));
}

/// P5 PASS: hotspot well below limit.
#[test]
fn p5_pass_below_limit() {
    assert_eq!(check_p5_thermal(0.5), Ok(()));
}

/// P5 FAIL: hotspot marginally above limit → re-floorplan required.
#[test]
fn p5_fail_above_limit() {
    let result = check_p5_thermal(1.001);
    assert!(matches!(
        result,
        Err(FalsifError::ThermalHotspot { hotspot_w_per_mm2 })
        if (hotspot_w_per_mm2 - 1.001_f64).abs() < 1e-9
    ));
}

/// P5 FAIL: extreme hotspot.
#[test]
fn p5_fail_extreme() {
    assert!(matches!(
        check_p5_thermal(50.0),
        Err(FalsifError::ThermalHotspot { .. })
    ));
}
