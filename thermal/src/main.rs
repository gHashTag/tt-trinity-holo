// holo-thermal-gate — P5 falsification gate for L-DPC24 Lane D'
// Hypothesis H₉ predicate P5: hotspot_w_per_mm2 > 1.0 at nominal → re-floorplan
// Threshold defined per issue #99: https://github.com/gHashTag/trinity-fpga/issues/99
// Anchor: φ²+φ⁻²=3

use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

/// P5 threshold from H₉: hotspot power density must not exceed 1.0 W/mm²
/// (typical natural-convection cooled die limit — see trinity-fpga#99).
/// If any report exceeds this, re-floorplanning is required.
const P5_HOTSPOT_THRESHOLD_W_PER_MM2: f64 = 1.0;

#[derive(Debug, Deserialize)]
struct ThermalReport {
    die: String,
    corner: String,
    hotspot_w_per_mm2: f64,
    ambient_c: f64,
}

fn main() {
    let reports_dir = PathBuf::from("thermal/reports");

    let entries = match fs::read_dir(&reports_dir) {
        Ok(e) => e,
        Err(err) => {
            eprintln!("ERROR: cannot read reports dir {:?}: {}", reports_dir, err);
            std::process::exit(2);
        }
    };

    let mut violators: Vec<String> = Vec::new();
    let mut checked = 0usize;

    for entry in entries {
        let entry = match entry {
            Ok(e) => e,
            Err(e) => {
                eprintln!("WARN: directory entry error: {}", e);
                continue;
            }
        };
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("json") {
            continue;
        }

        let raw = match fs::read_to_string(&path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("ERROR: cannot read {:?}: {}", path, e);
                std::process::exit(2);
            }
        };

        let report: ThermalReport = match serde_json::from_str(&raw) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("ERROR: invalid JSON in {:?}: {}", path, e);
                std::process::exit(2);
            }
        };

        checked += 1;
        let verdict = if report.hotspot_w_per_mm2 <= P5_HOTSPOT_THRESHOLD_W_PER_MM2 {
            "PASS"
        } else {
            let msg = format!(
                "FAIL  die={} corner={} hotspot={:.4} W/mm² > threshold={} W/mm² (P5 violated — re-floorplan required)",
                report.die, report.corner, report.hotspot_w_per_mm2, P5_HOTSPOT_THRESHOLD_W_PER_MM2
            );
            violators.push(msg.clone());
            "FAIL"
        };

        println!(
            "[{}] die={} corner={} hotspot={:.4} W/mm² ambient={:.1}°C  (file: {})",
            verdict,
            report.die,
            report.corner,
            report.hotspot_w_per_mm2,
            report.ambient_c,
            path.file_name().unwrap().to_string_lossy()
        );
    }

    println!();
    println!("--- holo-thermal-gate summary ---");
    println!("Reports checked : {}", checked);
    println!("Threshold (P5)  : {} W/mm²  [trinity-fpga#99]", P5_HOTSPOT_THRESHOLD_W_PER_MM2);
    println!("Violators       : {}", violators.len());

    if violators.is_empty() {
        println!("Result          : ALL PASS — P5 predicate satisfied (hotspot ≤ threshold)");
        std::process::exit(0);
    } else {
        println!("Result          : FAIL — P5 violated, re-floorplan required");
        for v in &violators {
            eprintln!("{}", v);
        }
        std::process::exit(1);
    }
}
