# BitROM BER Probe — Wave-29 Lane B Report

## Configuration

- DUT: rtl/holo_bitrom_bank.sv from PR #14 (898fc06)
- Reads simulated: 10^6 (CI default) / 10^9 (offline target)
- Seed: LFSR(0xDEADBEEF)
- Verdict: 🟡 SIM — pending silicon

## Results (initial CI run)

- total_reads: N (filled by `make report`)
- total_errors: N
- BER: N
- W28-G3 gate (BER ≤ 1e-9): PASS|FAIL

## Honest Status

🟡 SIM — silicon-verified 🟢 only on TTIHP27a return 2026-09-30.

This report is intentionally populated with placeholders at PR-open time.
The CI workflow (`make iverilog` or `make verilator`) fills the numbers above.
Running `make report` regenerates this file from a live sim run.

## W28-G3 Gate Rationale

| Condition | Verdict |
|---|---|
| total_errors = 0 after 10^6 reads | PASS (BER = 0 < 1e-9) |
| total_errors ≥ 1 after 10^6 reads | FAIL (BER ≥ 1e-6 >> 1e-9) |
| total_errors = 0 after 10^9 reads | PASS (direct gate satisfaction) |

Sentinel ROM uses pattern `4'b1010` for all 64 cells.  
Weight A (dir=0) = `2'b10`, Weight B (dir=1) = `2'b10`.  
Any deviation from `2'b10` in a valid in-range read is counted as a BER event.

## Reference Anchors

| Anchor | Value |
|---|---|
| DUT commit | 898fc06 (Lane W, tt-trinity-holo#14) |
| Algebraic | φ² + φ⁻² = 3 |
| DOI | [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |
| arXiv (BitROM) | [2509.08542](https://arxiv.org/abs/2509.08542) |
| ONE SHOT parent | [trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108) |

> Refs #108 · 🟡 SIM · Wave-29 Lane B · Author: Vasilev Dmitrii <admin@t27.ai>
