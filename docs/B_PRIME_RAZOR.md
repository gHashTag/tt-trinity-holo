# B_PRIME_RAZOR — Razor Flip-Flop with Shadow Sampling

**TTSKY26c HOLOGRAPHIC SKU · L-DPC24 Lane B'**

---

## Purpose

`holo_razor_ff` ports the **Razor flip-flop** error-detection scheme into the
TTSKY26c Holographic SKU as a stand-alone, synthesisable SystemVerilog cell.

The Razor scheme detects timing violations by comparing a main flip-flop
(clocked on the rising edge) against a shadow flip-flop (clocked on the
falling edge, i.e., half a cycle later).  If the logic value of the data input
`d` changes between the two sampling edges — as happens during a setup-time
violation or a glitch — the two outputs diverge and the `error_out` signal
asserts high within the same clock cycle.

---

## Schematic ASCII Art

```
              d
              │
    ┌─────────┼──────────────┐
    │         │              │
    │   ┌─────▼──────┐       │
    │   │ Main FF    │       │
    │   │ (posedge)  ├──► q  │
    │   └─────┬──────┘       │
    │       clk              │
    │                        │
    │   ┌─────▼──────┐       │
    │   │ Shadow FF  │       │
    │   │ (negedge)  ├──► q_shadow
    │   └─────┬──────┘       │
    │       clk              │
    └────────────────────────┘

              q ──┐
                  XOR ──► OR-reduction ──► error_out
       q_shadow ──┘
```

> **Interpretation:** `error_out` is the bitwise OR of `(q XOR q_shadow)`.
> Any bit mismatch causes immediate assertion.

---

## Port Table

| Port        | Dir    | Width   | Description                                     |
|-------------|--------|---------|-------------------------------------------------|
| `clk`       | input  | 1       | System clock                                    |
| `rst_n`     | input  | 1       | Synchronous active-low reset                    |
| `d`         | input  | `[W-1:0]` | Data input                                    |
| `q`         | output | `[W-1:0]` | Main output (rising-edge latch)               |
| `q_shadow`  | output | `[W-1:0]` | Shadow output (falling-edge latch)            |
| `error_out` | output | 1       | Asserts when `q` and `q_shadow` disagree        |

**Parameter**

| Name | Default | Description           |
|------|---------|-----------------------|
| `W`  | `32`    | Data-path width (bits)|

---

## Audit Grep

Verify R-SI-1 compliance (no `*` operator in source files):

```bash
grep -n ' \* ' rtl/holo_razor_ff.sv rtl/holo_razor_ff_tb.sv
```

Expected result: **empty** (no matches).

---

## R-SI-1 Attestation

The module `holo_razor_ff` and its testbench `holo_razor_ff_tb` contain **no
use of the `*` operator**.  All widths are expressed with replication syntax
`{W{1'b0}}` and reduction operators `|`, `^`; no arithmetic multiplication
appears anywhere.

Attested by: Vasilev Dmitrii <admin@t27.ai>  
Ref: DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## Reference Issue

[trinity-fpga#100](https://github.com/gHashTag/trinity-fpga/issues/100)

---

## Footer

```
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
```
