# Lane B — BitROM BER Probe Spec

**Lane:** B (L-DPC26 Wave-29)  
**Status:** `feat/l-dpc26/b-bitrom-ber-probe`  
**Author:** Vasilev Dmitrii `<admin@t27.ai>`  
**Base:** Lane W `holo_bitrom_bank` merged at `898fc06` on tt-trinity-holo#14  
**ONE SHOT parent:** [trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108)  
**Algebraic anchor:** φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## 1. Contract

| Property | Value |
|---|---|
| DUT | `holo_bitrom_bank` from PR #14 (`898fc06`) |
| Probe method | LFSR-driven random read patterns |
| LFSR seed | `0xDEADBEEF` (32-bit Fibonacci, taps 31,21,1,0) |
| Read rounds (CI) | 10^6 (1 000 000) |
| Read rounds (offline) | 10^9 (1 000 000 000) |
| BER gate W28-G3 | BER ≤ 1e-9 pre-silicon |
| R-SI-1 compliance | ZERO `*` operators in `probe.sv` |
| R18 compliance | `holo_bitrom_bank.sv` is unmodified; Lane B is additive only |
| R5-HONEST verdict | 🟡 SIM — silicon-verified 🟢 only on TTIHP27a return 2026-09-30 |

---

## 2. Background

Lane W (PR #14, `898fc06`) introduced `holo_bitrom_bank`: a bidirectional ROM bank encoding two ternary weights per physical cell (BitROM, Yoshioka Lab, ASP-DAC 2026 — [arXiv:2509.08542](https://arxiv.org/abs/2509.08542)).  
Lane B adds a simulation harness that statistically validates per-cell read fidelity under 10⁶ (CI) / 10⁹ (offline) random address patterns, locking the W28-G3 gate (BER ≤ 1e-9) before TTIHP27a silicon return.

---

## 3. Hypothesis (Pre-Registration G2)

**H:** The sentinel ROM pattern (`4'b1010` for all 64 cells) is read back without error for all in-range addresses under any LFSR-driven pattern sequence.

**Falsification predicate:** Refuted iff `total_errors > 0` in any sim run with `MAX_ROUNDS ≥ 10^6`.

**Stop rule:** First commit where CI `make iverilog` prints `W28-G3 gate: PASS` with `total_errors = 0`.

---

## 4. LFSR Design

32-bit Fibonacci LFSR, seed `0xDEADBEEF`, taps bit positions [31, 21, 1, 0]:

```
feedback = s[31] ^ s[21] ^ s[1] ^ s[0]
next     = {s[30:0], feedback}
```

Per round:
- `addr_i[ADDR_W-1:0]` = `lfsr_reg[ADDR_W-1:0]`  
- `dir_i`              = `lfsr_reg[ADDR_W]`

OOB addresses (cell_idx ≥ CELL_COUNT) are skipped from BER counting.

---

## 5. Module Hierarchy

```
sim/bitrom_ber_probe/probe.sv
└── u_dut : holo_bitrom_bank (rtl/holo_bitrom_bank.sv, 898fc06, UNMODIFIED)
```

---

## 6. File Map

| File | Purpose |
|---|---|
| `sim/bitrom_ber_probe/probe.sv` | Top-level BER probe harness (SystemVerilog) |
| `sim/bitrom_ber_probe/Makefile` | Build / run targets: `iverilog`, `verilator`, `report` |
| `sim/bitrom_ber_probe/report.md` | Honest BER report (R5-HONEST 🟡 SIM) |
| `docs/lever-stack/lane-b.md` | This spec document |

---

## 7. Port Specification (probe.sv parameters)

| Parameter | Default | Description |
|---|---|---|
| `CELL_COUNT` | 64 | Must match DUT |
| `WEIGHT_W` | 2 | Must match DUT |
| `ADDR_W` | 7 | Must match DUT |
| `LFSR_SEED` | `32'hDEADBEEF` | LFSR initial state |
| `MAX_ROUNDS` | 1_000_000 | Override via CLI for 1e9 offline run |

---

## 8. Makefile Targets

| Target | Command | Description |
|---|---|---|
| `iverilog` | `make iverilog` | Compile and run with iverilog/vvp |
| `verilator` | `make verilator` | Compile and run with Verilator (preferred for 1e9) |
| `report` | `make report` | Emit `report.md` from live sim run |
| `clean` | `make clean` | Remove build artefacts |

Override rounds: `make iverilog MAX_ROUNDS=1000000000`

---

## 9. Falsification Witnesses (R7)

| Predicate | Falsified iff |
|---|---|
| P-BER-1: `bitrom_no_star` | `*` operator found in `probe.sv` |
| P-BER-2: `bitrom_ber_gate` | `total_errors > 0` in any run with `MAX_ROUNDS ≥ 1e6` |
| P-BER-3: `bitrom_1cycle_latency` | `valid_o` not asserted exactly 1 cycle after `valid_i` |

---

## 10. Quantum Brain 1:1 Silicon Mapping

Lane B extends the **PHYS→SI** path:

- `holo_bitrom_bank` provides ternary weights (`{−1, 0, +1}` encoded in 2 bits) for the QB ISA `OP_BITROM_READ 0xE0`.
- BER ≤ 1e-9 gate ensures the ROM is physically reliable enough to substitute DRAM weight look-up at 20.8 TOPS/W (arXiv:2509.08542).
- Lane B closes the pre-silicon validation loop before TTIHP27a tape-out.

---

## 11. Pairwise Gate Tracking

| Gate | Target | Status |
|---|---|---|
| W28-G3 | BER ≤ 1e-9 | 🟡 SIM (silicon TBD 2026-09-30) |
| R-SI-1 | ZERO `*` in RTL | ✅ Verified by inspection |
| R18 | DUT unmodified | ✅ Lane B is additive only |
| R5-HONEST | 🟡 SIM label | ✅ Present in report.md |

---

## 12. Reference Anchors

| Anchor | Ref |
|---|---|
| Lane W BitROM base | tt-trinity-holo#14 at `898fc06` |
| Algebraic: φ²+φ⁻²=3 | [DOI 10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |
| BitROM paper | [arXiv:2509.08542](https://arxiv.org/abs/2509.08542) (Yoshioka Lab, ASP-DAC 2026) |
| ONE SHOT parent | [trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108) |
| Wave-28 prior lane V' | [docs/lever-stack/lane-v-prime.md](lane-v-prime.md) |

---

*φ² + φ⁻² = 3 · BER ≤ 1e-9 · 🟡 SIM · TTIHP27a 2026-09-30 · NEVER STOP*
