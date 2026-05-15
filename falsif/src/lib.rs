//! # holo-falsif
//!
//! L-DPC24 Lane E' — 5 Rust falsification witnesses for hypothesis H₉:
//! *measured TOPS/W ≥ 2000 on 1×2 HOLOGRAPHIC tile at Vdd=1.8V*
//!
//! One-shot issue: <https://github.com/gHashTag/trinity-fpga/issues/99>
//!
//! Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
//! R8 author: admin@t27.ai

use sha2::{Digest, Sha256};

/// Falsification error variants — one per predicate.
#[derive(Debug, PartialEq)]
pub enum FalsifError {
    /// P1: measured TOPS/W is below the 2000 threshold → REJECT H₉
    BelowThreshold { measured: f64, threshold: f64 },
    /// P2: R-marker cell hash does not match the frozen reference → NULL & VOID
    RMarkerMutation { expected: [u8; 32], actual: [u8; 32] },
    /// P3: Sacred ROM 75-cell hash has drifted → NULL & VOID
    SacredRomDrift { expected: [u8; 32], actual: [u8; 32] },
    /// P4: inter-die NoC stall exceeds 1 cycle → re-arch required
    NocStall { stall_cycles: u32 },
    /// P5: thermal hotspot exceeds 1 W/mm² at nominal → re-floorplan required
    ThermalHotspot { hotspot_w_per_mm2: f64 },
}

impl std::fmt::Display for FalsifError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            FalsifError::BelowThreshold { measured, threshold } => {
                write!(f, "P1 FAIL: measured {measured:.2} TOPS/W < threshold {threshold:.2} → REJECT H₉")
            }
            FalsifError::RMarkerMutation { expected, actual } => {
                write!(f, "P2 FAIL: R-marker hash mismatch — expected {expected:?}, got {actual:?} → NULL & VOID")
            }
            FalsifError::SacredRomDrift { expected, actual } => {
                write!(f, "P3 FAIL: Sacred ROM hash drift — expected {expected:?}, got {actual:?} → NULL & VOID")
            }
            FalsifError::NocStall { stall_cycles } => {
                write!(f, "P4 FAIL: NoC stall {stall_cycles} cycles > 1 → re-arch required")
            }
            FalsifError::ThermalHotspot { hotspot_w_per_mm2 } => {
                write!(f, "P5 FAIL: hotspot {hotspot_w_per_mm2:.3} W/mm² > 1.0 → re-floorplan required")
            }
        }
    }
}

impl std::error::Error for FalsifError {}

// ─────────────────────────────────────────────────────────────────────────────
// P1 — below_2000
// ─────────────────────────────────────────────────────────────────────────────

/// Check predicate P1: measured TOPS/W must be **≥ 2000.0**.
///
/// Returns `Ok(())` when the measurement satisfies H₉.
/// Returns `Err(FalsifError::BelowThreshold)` when it does not, falsifying H₉.
///
/// # Statistical note
/// // α_corrected = 0.002 = 0.01 / 5
pub fn check_p1_below_2000(measured_tops_per_w: f64) -> Result<(), FalsifError> {
    const THRESHOLD: f64 = 2000.0;
    if measured_tops_per_w < THRESHOLD {
        Err(FalsifError::BelowThreshold {
            measured: measured_tops_per_w,
            threshold: THRESHOLD,
        })
    } else {
        Ok(())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// P2 — R_SI_1_breach  (R15 R-marker cell mutation guard)
// ─────────────────────────────────────────────────────────────────────────────

/// Check predicate P2: the SHA-256 hash of `r_marker_value` must equal `frozen_hash`.
///
/// A mismatch indicates the R15 R-marker cell has been mutated, rendering the
/// measurement NULL & VOID.
///
/// # Statistical note
/// // α_corrected = 0.002 = 0.01 / 5
pub fn check_p2_r_si_1_breach(
    r_marker_value: u64,
    frozen_hash: [u8; 32],
) -> Result<(), FalsifError> {
    let mut hasher = Sha256::new();
    hasher.update(r_marker_value.to_le_bytes());
    let actual: [u8; 32] = hasher.finalize().into();
    if actual != frozen_hash {
        Err(FalsifError::RMarkerMutation {
            expected: frozen_hash,
            actual,
        })
    } else {
        Ok(())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// P3 — R15_breach  (Sacred ROM 75-cell hash integrity)
// ─────────────────────────────────────────────────────────────────────────────

/// Check predicate P3: the SHA-256 hash over all 75 cells of `sacred_rom`
/// must equal `frozen_rom_hash`.
///
/// Any drift in the 75-cell ROM renders the measurement NULL & VOID.
///
/// # Statistical note
/// // α_corrected = 0.002 = 0.01 / 5
pub fn check_p3_r15_breach(
    sacred_rom: &[u64; 75],
    frozen_rom_hash: [u8; 32],
) -> Result<(), FalsifError> {
    let mut hasher = Sha256::new();
    for cell in sacred_rom.iter() {
        hasher.update(cell.to_le_bytes());
    }
    let actual: [u8; 32] = hasher.finalize().into();
    if actual != frozen_rom_hash {
        Err(FalsifError::SacredRomDrift {
            expected: frozen_rom_hash,
            actual,
        })
    } else {
        Ok(())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// P4 — noc_stall  (inter-die NoC stall guard)
// ─────────────────────────────────────────────────────────────────────────────

/// Check predicate P4: inter-die NoC `stall_cycles` must be **≤ 1**.
///
/// More than 1 stall cycle triggers a re-architecture requirement.
///
/// # Statistical note
/// // α_corrected = 0.002 = 0.01 / 5
pub fn check_p4_noc_stall(stall_cycles: u32) -> Result<(), FalsifError> {
    const MAX_STALL: u32 = 1;
    if stall_cycles > MAX_STALL {
        Err(FalsifError::NocStall { stall_cycles })
    } else {
        Ok(())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// P5 — thermal  (hotspot power density guard)
// ─────────────────────────────────────────────────────────────────────────────

/// Check predicate P5: hotspot power density must be **≤ 1.0 W/mm²** at nominal.
///
/// Exceeding this threshold triggers a re-floorplan requirement.
///
/// # Statistical note
/// // α_corrected = 0.002 = 0.01 / 5
pub fn check_p5_thermal(hotspot_w_per_mm2: f64) -> Result<(), FalsifError> {
    const MAX_DENSITY: f64 = 1.0;
    if hotspot_w_per_mm2 > MAX_DENSITY {
        Err(FalsifError::ThermalHotspot { hotspot_w_per_mm2 })
    } else {
        Ok(())
    }
}
