# LUT PE Energy Probe — Wave-29 Lane E Report

> **Verdict: 🟡 SIM** — Results are simulation estimates only.
> Silicon verification pending TTIHP27a tapeout return **2026-09-30**.
> Do NOT promote to 🟢 SILICON until measured on physical die.

## Configuration

| Parameter | Value |
|---|---|
| DUT | `rtl/holo_lut_pe.sv` from PR #19 (commit `91c164ac`) |
| Baseline | `sim/lut_energy_probe/shift_add_baseline.sv` (this PR) |
| Vectors | 10⁵ LFSR-driven random (16-bit Galois LFSR, poly x¹⁶+x¹⁴+x¹³+x¹¹+1) |
| Cload assumption | 1 fF (typical SG13G2 cell load) |
| VDD | 1.2 V (SG13G2 nominal) |
| Toggle metric | Total net transitions / op (output data + addr + valid signals) |
| W28-G2 gate | LUT PE energy/op ≤ 2× shift-add baseline |
| ONE SHOT | [gHashTag/trinity-fpga#108](https://github.com/gHashTag/trinity-fpga/issues/108) |
| Anchor | φ² + φ⁻² = 3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877) |

## Results

- LUT PE toggles/op: N
- Shift-add toggles/op: N
- Ratio: N×
- W28-G2 gate (≤ 2×): PASS|FAIL

> Run `make report` from `sim/lut_energy_probe/` to populate results with live simulation data.

## Methodology

Toggle count is used as a proxy for switching activity energy:

```
E_op ≈ Σ(toggles) × Cload × VDD²
```

Both DUT and baseline share the same Cload and VDD assumptions, so the
energy ratio equals the toggle ratio. This is an RTL-level approximation;
gate-level power analysis (OpenLane post-route) is deferred to the silicon
bring-up phase.

## Falsifiability Witness

Per R8, this probe is falsifiable if:
- TTIHP27a silicon measurements show DUT energy/op > 2× shift-add → W28-G2 **FAIL**
- OpenLane gate-level power sim contradicts the toggle-ratio proxy by > 20%

## LUT PE Architecture Note

`holo_lut_pe` replaces arithmetic computation with a 1-cycle table lookup
(`lut_mem[addr]`), eliminating all adder/XOR chains for the compute path.
The expected switching advantage comes from:

1. Fewer logic stages (LUT read vs shift-add pipeline)
2. Input-selective activity (only addressed entry propagates)
3. No carry-chain toggling (shift-add generates carry bits on nearly every op)

The arXiv 2511.21910 paper claims 1.4× improvement over shift-add at 28nm;
this probe targets confirming the claim via RTL-level switching activity
under LFSR-random workloads before silicon.

## Refs

- Refs #108
- PR #19 (holo_lut_pe): commit `91c164ac`
- arXiv 2511.21910 — "Platinum LUT PE: 1534 GOPS @ 0.96 mm² @ 500 MHz @ 28nm"
- DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

*Signed-off-by: Vasilev Dmitrii <admin@t27.ai>*
