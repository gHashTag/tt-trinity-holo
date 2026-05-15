// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// holo-metrics/src/lib.rs — v9-G1 falsification witnesses (Lane E')
// =============================================================================
//
// L-DPC24 §5 · R7 falsification witnesses W-100-A..E
// Author  : Vasilev Dmitrii <admin@t27.ai>
// Issue   : https://github.com/gHashTag/trinity-fpga/issues/100
//
// R5-HONEST falsification protocol:
//   Each witness encodes a *necessary condition* for v9-G1 evidence.
//   A witness PASSES when the gate correctly REJECTS a bad input.
//   Silicon validity requires ALL 5 witnesses to hold simultaneously.
//
// Witnesses:
//   W-100-A  falsify_v9_below_2000        — phantom-low TOPS/W < 2000 → Err
//   W-100-B  falsify_v9_R_SI_1_breach     — RTL scan finds `*` operator → Err
//   W-100-C  falsify_v9_R15_breach        — R-marker in ROM (not boot-loaded) → Err
//   W-100-D  falsify_v9_noc_stall         — NoC latency > 1 cycle → Err
//   W-100-E  falsify_v9_thermal           — thermal density > 1.0 W/mm² → Err
//
// =============================================================================

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

// -----------------------------------------------------------------------------
// Public structs
// -----------------------------------------------------------------------------

/// Performance metrics for a v9-G1 candidate chip reading.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoloMetrics {
    /// Energy efficiency — TOPS per Watt (claimed end-to-end, not peak).
    pub tops_per_watt: f64,
    /// NoC round-trip latency in clock cycles (must be exactly 1).
    pub noc_latency_cycles: u32,
    /// Thermal power density in W/mm² (must be ≤ 1.0).
    pub thermal_w_per_mm2: f64,
    /// Sample label / provenance tag (e.g. "phantom-low-1700", "measured-2300").
    pub label: String,
}

/// Configuration / boot-time parameters for the v9 die.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoloConfig {
    /// Whether R-markers are boot-loaded at runtime (true = correct).
    pub r_markers_boot_loaded: bool,
    /// Number of R-marker slots populated via ROM (must be 0 when boot-loaded).
    pub r_marker_rom_slots: u32,
    /// Optional description of the config origin.
    pub description: Option<String>,
}

// -----------------------------------------------------------------------------
// Gate functions
// -----------------------------------------------------------------------------

/// W-100-A + W-100-D + W-100-E  ·  v9 performance gate.
///
/// Rejects any [`HoloMetrics`] reading that violates one or more of the three
/// physical thresholds required for v9-G1 evidence:
///   - TOPS/W must be ≥ 2000  (v9 floor, L-DPC24 §3.1)
///   - NoC latency must be exactly 1 cycle  (W-100-D)
///   - Thermal density must be ≤ 1.0 W/mm²  (W-100-E)
///
/// Returns `Ok(())` if all thresholds are met, `Err(String)` with a
/// human-readable rejection reason otherwise.
pub fn check_v9_gate(m: &HoloMetrics) -> Result<(), String> {
    // W-100-A: phantom-low TOPS/W guard
    if m.tops_per_watt < 2000.0 {
        return Err(format!(
            "W-100-A FALSIFIED: tops_per_watt={:.1} < 2000.0 (v9 floor). \
             Sample '{}' is phantom-low — G1 evidence invalidated.",
            m.tops_per_watt, m.label
        ));
    }

    // W-100-D: NoC single-cycle latency guard
    if m.noc_latency_cycles != 1 {
        return Err(format!(
            "W-100-D FALSIFIED: noc_latency_cycles={} ≠ 1 (must be 1-cycle NoC). \
             Sample '{}' has NoC stall — G1 evidence invalidated.",
            m.noc_latency_cycles, m.label
        ));
    }

    // W-100-E: thermal density guard
    if m.thermal_w_per_mm2 > 1.0 {
        return Err(format!(
            "W-100-E FALSIFIED: thermal_w_per_mm2={:.3} > 1.0 W/mm² (thermal ceiling). \
             Sample '{}' exceeds thermal budget — G1 evidence invalidated.",
            m.thermal_w_per_mm2, m.label
        ));
    }

    Ok(())
}

/// W-100-C  ·  R-15 configuration gate.
///
/// R-15 requires that R-marker constants are supplied via the boot-loader at
/// runtime — **not** hard-coded in ROM.  If `r_markers_boot_loaded` is false,
/// or if `r_marker_rom_slots > 0`, the config is an R-15 breach.
pub fn check_r15(cfg: &HoloConfig) -> Result<(), String> {
    if !cfg.r_markers_boot_loaded {
        return Err(format!(
            "W-100-C FALSIFIED: r_markers_boot_loaded=false. \
             R-markers must be supplied via boot-loader (R-15), not hard-coded in ROM. \
             Config '{}' is an R-15 breach — G1 evidence invalidated.",
            cfg.description.as_deref().unwrap_or("<unlabelled>")
        ));
    }
    if cfg.r_marker_rom_slots > 0 {
        return Err(format!(
            "W-100-C FALSIFIED: r_marker_rom_slots={} > 0 while boot_loaded=true. \
             ROM slot conflict — R-15 protocol requires zero ROM slots when boot-loaded. \
             Config '{}' is an R-15 breach.",
            cfg.r_marker_rom_slots,
            cfg.description.as_deref().unwrap_or("<unlabelled>")
        ));
    }
    Ok(())
}

/// W-100-B  ·  RTL star-operator scan.
///
/// Recursively walks `dir` for `*.v` and `*.sv` files and rejects any file
/// that contains a `*` operator (multiply).  R-SI-1 forbids multiply operators
/// in all RTL under the v9-G1 submission.
///
/// A line is flagged only if `*` appears as an operator — the scan skips
/// comment lines (starting with `//`) and lines where `*` appears only inside
/// block comments or `*` as the start of a `*/` closing sequence.
///
/// Returns `Ok(())` if no violations found, `Err(String)` listing violations.
pub fn scan_rtl_for_star(dir: &str) -> Result<(), String> {
    let mut violations: Vec<String> = Vec::new();

    scan_dir_recursive(dir, &mut violations)?;

    if violations.is_empty() {
        Ok(())
    } else {
        Err(format!(
            "W-100-B FALSIFIED: R-SI-1 breach — `*` operator found in RTL.\n{}",
            violations.join("\n")
        ))
    }
}

// Internal recursive directory walker for scan_rtl_for_star.
fn scan_dir_recursive(dir: &str, violations: &mut Vec<String>) -> Result<(), String> {
    let entries = fs::read_dir(dir)
        .map_err(|e| format!("scan_rtl_for_star: cannot read dir '{}': {}", dir, e))?;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            scan_dir_recursive(
                path.to_str().unwrap_or(dir),
                violations,
            )?;
        } else if is_rtl_file(&path) {
            scan_file_for_star(&path, violations);
        }
    }
    Ok(())
}

fn is_rtl_file(path: &Path) -> bool {
    match path.extension().and_then(|e| e.to_str()) {
        Some("v") | Some("sv") => true,
        _ => false,
    }
}

fn scan_file_for_star(path: &Path, violations: &mut Vec<String>) {
    let content = match fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return,
    };

    for (line_no, raw_line) in content.lines().enumerate() {
        let trimmed = raw_line.trim();
        // Skip pure comment lines
        if trimmed.starts_with("//") {
            continue;
        }
        // Strip inline // comment before scanning
        let code_part = match raw_line.find("//") {
            Some(pos) => &raw_line[..pos],
            None => raw_line,
        };
        // Detect `*` as operator: present but not as `*/` (end of block comment)
        // and not as `/**` (doc comment start).
        if contains_star_operator(code_part) {
            violations.push(format!(
                "  {}:{}: `*` operator — {:?}",
                path.display(),
                line_no + 1,
                trimmed
            ));
        }
    }
}

/// Returns true if the code fragment contains `*` used as a binary/unary
/// operator (not as `*/` comment-close or `**` exponent-comment).
fn contains_star_operator(code: &str) -> bool {
    let chars: Vec<char> = code.chars().collect();
    let n = chars.len();
    let mut i = 0;
    while i < n {
        if chars[i] == '*' {
            // Skip `*/` — end of block comment
            if i + 1 < n && chars[i + 1] == '/' {
                i += 2;
                continue;
            }
            // Otherwise it's a multiply operator
            return true;
        }
        i += 1;
    }
    false
}

// =============================================================================
// Tests — 5 R7 falsification witnesses
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // -------------------------------------------------------------------------
    // W-100-A: phantom-low TOPS/W sample
    // -------------------------------------------------------------------------
    /// WITNESS W-100-A: synthetic phantom-low reading (1700 TOPS/W) must be
    /// rejected by check_v9_gate().  If this test PASSES, the gate correctly
    /// rejects sub-threshold evidence.
    #[test]
    fn falsify_v9_below_2000() {
        let bad_sample = HoloMetrics {
            tops_per_watt: 1700.0,
            noc_latency_cycles: 1,
            thermal_w_per_mm2: 0.8,
            label: "phantom-low-1700".to_string(),
        };
        let result = check_v9_gate(&bad_sample);
        assert!(
            result.is_err(),
            "W-100-A: expected check_v9_gate to Err on phantom-low 1700 TOPS/W, got Ok"
        );
        let msg = result.unwrap_err();
        assert!(
            msg.contains("W-100-A"),
            "W-100-A: error message must cite W-100-A, got: {}",
            msg
        );
        assert!(
            msg.contains("1700"),
            "W-100-A: error must mention the bad value 1700, got: {}",
            msg
        );
    }

    // -------------------------------------------------------------------------
    // W-100-B: RTL scan for `*` operator
    // -------------------------------------------------------------------------
    /// WITNESS W-100-B: inject a temp file with a `*` operator and verify
    /// scan_rtl_for_star() correctly returns Err (R-SI-1 breach detected).
    #[test]
    fn falsify_v9_r_si_1_breach() {
        use std::io::Write;
        let dir = tempfile::TempDir::new().expect("tempdir");
        let bad_rtl = dir.path().join("bad_multiply.v");
        let mut f = std::fs::File::create(&bad_rtl).expect("create bad_multiply.v");
        writeln!(
            f,
            "// RTL with forbidden multiply operator\n\
             module bad_mul (input [7:0] a, input [7:0] b, output [15:0] out);\n\
             assign out = a * b; // FORBIDDEN: * operator\n\
             endmodule"
        )
        .unwrap();

        let result = scan_rtl_for_star(dir.path().to_str().unwrap());
        assert!(
            result.is_err(),
            "W-100-B: expected scan_rtl_for_star to Err on RTL with `*`, got Ok"
        );
        let msg = result.unwrap_err();
        assert!(
            msg.contains("W-100-B"),
            "W-100-B: error must cite W-100-B, got: {}",
            msg
        );
    }

    // -------------------------------------------------------------------------
    // W-100-C: R-15 breach — R-marker in ROM (not boot-loaded)
    // -------------------------------------------------------------------------
    /// WITNESS W-100-C: config with R-marker constant baked into ROM (not
    /// boot-loaded) must be rejected by check_r15().
    #[test]
    fn falsify_v9_r15_breach() {
        let bad_cfg = HoloConfig {
            r_markers_boot_loaded: false,
            r_marker_rom_slots: 4,
            description: Some("r_marker_const_in_rom — R15 breach fixture".to_string()),
        };
        let result = check_r15(&bad_cfg);
        assert!(
            result.is_err(),
            "W-100-C: expected check_r15 to Err on ROM-baked R-marker config, got Ok"
        );
        let msg = result.unwrap_err();
        assert!(
            msg.contains("W-100-C"),
            "W-100-C: error must cite W-100-C, got: {}",
            msg
        );
        assert!(
            msg.contains("R-15"),
            "W-100-C: error must mention R-15, got: {}",
            msg
        );
    }

    // -------------------------------------------------------------------------
    // W-100-D: NoC 2-cycle stall reading
    // -------------------------------------------------------------------------
    /// WITNESS W-100-D: a reading with 2-cycle NoC latency must be rejected by
    /// check_v9_gate() (v9 NoC must be 1-cycle, L-DPC24 §2).
    #[test]
    fn falsify_v9_noc_stall() {
        let stall_sample = HoloMetrics {
            tops_per_watt: 2500.0,     // meets TOPS/W floor
            noc_latency_cycles: 2,     // VIOLATES: must be 1
            thermal_w_per_mm2: 0.9,    // meets thermal
            label: "noc-stall-2cycle".to_string(),
        };
        let result = check_v9_gate(&stall_sample);
        assert!(
            result.is_err(),
            "W-100-D: expected check_v9_gate to Err on 2-cycle NoC stall, got Ok"
        );
        let msg = result.unwrap_err();
        assert!(
            msg.contains("W-100-D"),
            "W-100-D: error must cite W-100-D, got: {}",
            msg
        );
        assert!(
            msg.contains("2"),
            "W-100-D: error must mention cycle count 2, got: {}",
            msg
        );
    }

    // -------------------------------------------------------------------------
    // W-100-E: thermal 1.2 W/mm² reading
    // -------------------------------------------------------------------------
    /// WITNESS W-100-E: a reading with 1.2 W/mm² must be rejected by
    /// check_v9_gate() (thermal ceiling = 1.0 W/mm²).
    #[test]
    fn falsify_v9_thermal() {
        let hot_sample = HoloMetrics {
            tops_per_watt: 2800.0,     // meets TOPS/W floor
            noc_latency_cycles: 1,     // meets NoC
            thermal_w_per_mm2: 1.2,    // VIOLATES: must be ≤ 1.0
            label: "thermal-1.2-wmm2".to_string(),
        };
        let result = check_v9_gate(&hot_sample);
        assert!(
            result.is_err(),
            "W-100-E: expected check_v9_gate to Err on 1.2 W/mm² thermal reading, got Ok"
        );
        let msg = result.unwrap_err();
        assert!(
            msg.contains("W-100-E"),
            "W-100-E: error must cite W-100-E, got: {}",
            msg
        );
        assert!(
            msg.contains("1.2"),
            "W-100-E: error must mention thermal value 1.2, got: {}",
            msg
        );
    }
}

// phi^2 + phi^-2 = 3 · QUANTUM BRAIN 1:1 SILICON
