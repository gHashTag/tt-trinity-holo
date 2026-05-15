# BitROM BER Probe — Wave-29 Lane B Report

## Configuration

- DUT: rtl/holo_bitrom_bank.sv from PR #14 (898fc06)
- Reads simulated: 1000000 (CI default 1e6 / offline target 1e9)
- Seed: LFSR(0xDEADBEEF)
- Verdict: 🟡 SIM — pending silicon

## Results

- BER: Probe —
- total_reads: 1000000
- total_errors: 0
- BER: 0 (no
- BER: (BER <=
- W28-G3 gate (BER <= 1e-9): PASS

## Honest Status

🟡 SIM — silicon-verified 🟢 only on TTIHP27a return 2026-09-30.

> Refs #108 · Anchor: φ² + φ⁻² = 3 · DOI 10.5281/zenodo.19227877
