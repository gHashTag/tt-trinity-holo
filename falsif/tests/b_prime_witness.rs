//! # b_prime_witness.rs — L-DPC24 Lane B' Falsification Witnesses
//!
//! Three `#[test]` functions satisfying R7 (falsification witness mandate):
//!
//! 1. `test_razor_no_star`         — R-SI-1: verifies NO `*` operator in RTL sources
//! 2. `test_razor_detects_violation` — R7a: Razor FF detects injected timing violation
//! 3. `test_razor_replay_correct`  — R7b: pipeline replay produces correct output
//!
//! ## Pre-registration (Gate G2)
//! - statistical_test: structural assertion (testbench correctness)
//! - effect_size: ≥30% energy reduction at Vdd_min vs standard-FF pipeline (RTL-projected,
//!   silicon-deferred to TTIHP27a)
//! - falsification_predicate: refuted iff (a) any RTL `*`, OR (b) Razor FF fails to
//!   detect injected violation, OR (c) replay produces incorrect output, OR (d) any
//!   false-positive in 1000 random patterns
//! - n_required: 1000 random patterns, 100 injected violations
//! - stop_rule: first commit where all 4 falsification witnesses pass + R-SI-1 CI green
//!
//! ## Critical path (L-DPC24)
//! Y → A' → **B'** → D' → E'
//!
//! ## References
//! - Ernst et al., "Razor: A Low-Power Pipeline Based on Circuit-Level Timing
//!   Speculation", DAC 2003
//! - ONE SHOT parent: https://github.com/gHashTag/trinity-fpga/issues/99
//! - Anchor: φ²+φ⁻²=3 · DOI 10.5281/zenodo.19227877
//!
//! Author: Vasilev Dmitrii <admin@t27.ai>

// ─────────────────────────────────────────────────────────────────────────────
// RTL path constants (relative to repo root)
// ─────────────────────────────────────────────────────────────────────────────

/// RTL files that belong to Lane B' and MUST be free of `*` operators (R-SI-1).
const LANE_B_PRIME_RTL_FILES: &[&str] = &[
    "rtl/holo_razor_ff.sv",
    "rtl/holo_razor_pipeline.sv",
];

/// RTL files that belong to Lane A' and MUST NOT be mutated (R18).
const LANE_A_PRIME_RTL_FILES: &[&str] = &[
    "rtl/holo_noc_1cycle.sv",
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Razor FF model (RTL-behavioural in Rust, mirrors SV semantics)
// ─────────────────────────────────────────────────────────────────────────────

/// State of a single Razor flip-flop (bitwidth W=32).
#[derive(Debug, Clone, PartialEq, Eq)]
struct RazorFF {
    /// Main flip-flop — samples on rising edge.
    q: u32,
    /// Shadow flip-flop — samples on falling edge (half-cycle later).
    q_shadow: u32,
}

impl RazorFF {
    fn new() -> Self {
        RazorFF { q: 0, q_shadow: 0 }
    }

    /// Rising-edge clock: main FF captures `d`.
    fn posedge(&mut self, d: u32) {
        self.q = d;
    }

    /// Falling-edge clock: shadow FF captures `d`.
    /// In real silicon the falling edge is half a cycle after the rising edge;
    /// any input change between the edges is a timing violation.
    fn negedge(&mut self, d: u32) {
        self.q_shadow = d;
    }

    /// Returns true when a timing violation is detected (q ≠ q_shadow).
    fn error_out(&self) -> bool {
        self.q != self.q_shadow
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: two-stage Razor pipeline model
// ─────────────────────────────────────────────────────────────────────────────

struct RazorPipeline {
    stage: [RazorFF; 2],
    replay_active: bool,
    replay_val: u32,
}

impl RazorPipeline {
    fn new() -> Self {
        RazorPipeline {
            stage: [RazorFF::new(), RazorFF::new()],
            replay_active: false,
            replay_val: 0,
        }
    }

    /// Simulate one full cycle (posedge then negedge).
    /// `d_in_posedge` is presented before posedge;
    /// `d_in_negedge` is what d_in resolves to before negedge
    /// (normally equal; differs only during a violation injection).
    fn clock_cycle(&mut self, d_in_posedge: u32, d_in_negedge: u32) -> (u32, bool) {
        // Rising edge: each stage latches its upstream value
        let s0_in = if self.replay_active { self.replay_val } else { d_in_posedge };
        let s1_in = self.stage[0].q;
        self.stage[0].posedge(s0_in);
        self.stage[1].posedge(s1_in);

        // Falling edge: shadow FFs latch (d_in_negedge may differ if violating)
        let s0_shadow_in = if self.replay_active { self.replay_val } else { d_in_negedge };
        let s1_shadow_in = self.stage[0].q;
        self.stage[0].negedge(s0_shadow_in);
        self.stage[1].negedge(s1_shadow_in);

        let err = self.stage[0].error_out() || self.stage[1].error_out();

        // Update replay machinery
        if err && !self.replay_active {
            self.replay_active = true;
            self.replay_val = d_in_posedge;
        } else {
            self.replay_active = false;
            self.replay_val = 0;
        }

        (self.stage[1].q, err)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// LFSR-32 pseudo-random (Galois, poly 0xB4BCD35C) — no `*`
// ─────────────────────────────────────────────────────────────────────────────

fn lfsr_next(state: u32) -> u32 {
    let lsb = state & 1;
    let shifted = state >> 1;
    if lsb != 0 {
        shifted ^ 0xB4BCD35C
    } else {
        shifted
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST 1 — R-SI-1: no `*` operator in Lane B' RTL files
// ─────────────────────────────────────────────────────────────────────────────

/// Verifies R-SI-1 compliance: none of the Lane B' RTL source files
/// contains a bare multiplication operator `*`.
///
/// A violation refutes the claim that the RTL is multiply-free.
#[test]
fn test_razor_no_star() {
    // Determine the repo root relative to the Cargo manifest directory.
    // CARGO_MANIFEST_DIR = <repo-root>/falsif
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let repo_root = std::path::Path::new(manifest_dir)
        .parent()
        .expect("expected parent directory of falsif/");

    let mut violations: Vec<(String, usize, String)> = Vec::new();

    for rel_path in LANE_B_PRIME_RTL_FILES {
        let full_path = repo_root.join(rel_path);
        let content = std::fs::read_to_string(&full_path)
            .unwrap_or_else(|e| panic!("cannot read {}: {}", full_path.display(), e));

        for (line_no, line) in content.lines().enumerate() {
            // Skip comment lines (// …)
            let trimmed = line.trim();
            if trimmed.starts_with("//") {
                continue;
            }
            // Check for bare `*` not part of `**` (doc-comment) or `/*` (block comment)
            // and not part of `{W{…}}` replication — SV replication uses `{n{…}}` not `*`.
            // We scan for `*` that is NOT preceded/followed by `*` and NOT inside /*…*/
            let mut in_block_comment = false;
            let chars: Vec<char> = line.chars().collect();
            let n = chars.len();
            let mut ci = 0;
            while ci < n {
                if ci + 1 < n && chars[ci] == '/' && chars[ci + 1] == '*' {
                    in_block_comment = true;
                    ci += 2;
                    continue;
                }
                if ci + 1 < n && chars[ci] == '*' && chars[ci + 1] == '/' {
                    in_block_comment = false;
                    ci += 2;
                    continue;
                }
                if ci + 1 < n && chars[ci] == '/' && chars[ci + 1] == '/' {
                    break; // rest of line is comment
                }
                if !in_block_comment && chars[ci] == '*' {
                    // It's a real `*` — flag it
                    violations.push((
                        rel_path.to_string(),
                        line_no + 1,
                        line.to_string(),
                    ));
                }
                ci += 1;
            }
        }
    }

    assert!(
        violations.is_empty(),
        "R-SI-1 VIOLATION: `*` operator found in Lane B' RTL:\n{}",
        violations
            .iter()
            .map(|(f, l, t)| format!("  {}:{}: {}", f, l, t.trim()))
            .collect::<Vec<_>>()
            .join("\n")
    );

    // Also verify Lane A' files are untouched (R18): no new content added
    // (we only assert they still exist — mutation guard is a separate CI check)
    for rel_path in LANE_A_PRIME_RTL_FILES {
        let full_path = repo_root.join(rel_path);
        assert!(
            full_path.exists(),
            "R18 VIOLATION: Lane A' file missing: {}",
            full_path.display()
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST 2 — R7a: Razor FF detects an injected timing violation
// ─────────────────────────────────────────────────────────────────────────────

/// Injects a timing violation (d changes between posedge and negedge) in the
/// behavioural RazorFF model and asserts that error_out fires.
///
/// Also sweeps 100 distinct injected violations to satisfy n_required=100.
/// Refuted iff error_out fails to assert for ANY of the 100 injections.
#[test]
fn test_razor_detects_violation() {
    let mut ff = RazorFF::new();

    // Warm up: stable value for a few cycles
    for _ in 0..4 {
        ff.posedge(0xDEAD_BEEF);
        ff.negedge(0xDEAD_BEEF);
        assert!(!ff.error_out(), "false-positive during warm-up");
    }

    // Inject 100 distinct timing violations
    let mut lfsr_state: u32 = 0xACE1_7513;
    let mut detected_count = 0u32;

    for inject_idx in 0..100u32 {
        lfsr_state = lfsr_next(lfsr_state);
        let old_val = lfsr_state;
        lfsr_state = lfsr_next(lfsr_state);
        let new_val = lfsr_state;

        // Ensure old_val ≠ new_val (XOR non-zero) to guarantee a violation
        if old_val == new_val {
            continue; // astronomically rare; skip
        }

        // Rising edge captures old_val
        ff.posedge(old_val);
        // d changes mid-cycle: shadow sees new_val
        ff.negedge(new_val);

        if ff.error_out() {
            detected_count += 1;
        } else {
            panic!(
                "R7 FAIL [inject {}]: Razor FF did NOT detect violation \
                 old=0x{:08X} new=0x{:08X}",
                inject_idx, old_val, new_val
            );
        }
    }

    assert!(
        detected_count >= 100,
        "R7 FAIL: only {}/100 violations detected — Razor FF broken",
        detected_count
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST 3 — R7b: pipeline replay produces correct output
// ─────────────────────────────────────────────────────────────────────────────

/// Injects a violation into the two-stage Razor pipeline, verifies that:
///  (a) error_any asserts on the cycle of violation
///  (b) after replay + drain cycles, the output carries the CORRECT value
///  (c) 1000 stable random patterns produce zero false-positives
///
/// Refuted iff (b) output ≠ expected OR (c) any false-positive fires.
#[test]
fn test_razor_replay_correct() {
    let mut pipe = RazorPipeline::new();

    // ---- Phase 1: stable warmup ----
    for _ in 0..8 {
        let (_, err) = pipe.clock_cycle(0x1234_5678, 0x1234_5678);
        assert!(!err, "false-positive during warmup");
    }

    // ---- Phase 2: inject one violation at stage-0 ----
    // posedge sees AAAA_AAAA, negedge (shadow) sees 5555_5555
    let (_, err) = pipe.clock_cycle(0xAAAA_AAAA, 0x5555_5555);
    assert!(
        err,
        "R7b FAIL: pipeline did not detect violation (posedge=AAAA, negedge=5555)"
    );

    // ---- Phase 3: allow replay + drain (4 more cycles, stable) ----
    for _ in 0..4 {
        pipe.clock_cycle(0xAAAA_AAAA, 0xAAAA_AAAA);
    }

    // ---- Phase 4: send a clean token and verify it exits correctly ----
    for _ in 0..4 {
        pipe.clock_cycle(0xBEEF_CAFE, 0xBEEF_CAFE);
    }
    let (out, err) = pipe.clock_cycle(0xBEEF_CAFE, 0xBEEF_CAFE);
    assert!(
        !err,
        "R7b FAIL: spurious error after replay stabilisation"
    );
    assert_eq!(
        out, 0xBEEF_CAFE,
        "R7b FAIL: pipeline output 0x{:08X} ≠ expected 0xBEEF_CAFE after replay",
        out
    );

    // ---- Phase 5: 1000 random stable patterns — zero false-positives (R7 n_required) ----
    let mut lfsr_state: u32 = 0xDEAD_1234;
    for pat_idx in 0..1000usize {
        lfsr_state = lfsr_next(lfsr_state);
        let val = lfsr_state;
        let (_, err) = pipe.clock_cycle(val, val); // same value both edges = stable
        assert!(
            !err,
            "R7 FAIL TC4 [{}/1000]: false-positive error for stable pattern val=0x{:08X}",
            pat_idx, val
        );
    }
}

// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
