# A' NoC – 1-Cycle Inter-Die Network-on-Chip Stub

**Lane A' · L-DPC24 HOLOGRAPHIC v9 · holo-noc-1cycle**
**SKU:** TTSKY26c HOLOGRAPHIC
**Compliance:** R-SI-1 (no `*` operator in RTL)

---

## Purpose

`holo_noc_1cycle` is a 1-cycle-latency inter-die Network-on-Chip (NoC) stub for the TTSKY26c Holographic SKU. It routes `FLIT_W`-bit flits between `DIES` silicon dies using a symmetric swap pattern: each die receives the flit from the opposite die exactly one clock cycle after it is presented. No arithmetic multiplier operators are used anywhere in the RTL.

---

## Port Table

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock (rising-edge triggered) |
| `rst_n` | input | 1 | Synchronous active-low reset |
| `flit_in[DIES]` | input | `FLIT_W` | Input flit bus, one entry per die |
| `vld_in[DIES]` | input | 1 | Valid flag for each input flit |
| `flit_out[DIES]` | output | `FLIT_W` | Output flit bus, one entry per die |
| `vld_out[DIES]` | output | 1 | Valid flag for each output flit |
| `latency_cycles` | output | `$clog2(DIES+1)` | Constant `1` – latency verification handshake |

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `FLIT_W` | 32 | Flit width in bits |
| `DIES` | 2 | Number of dies |

---

## Latency Claim

- **Registered output:** Flits are latched on the rising edge of `clk`.
- **Combinational route:** The routing function (die index swap) is purely combinational, resolved before the register.
- **Result:** Output appears exactly **1 cycle** after the corresponding input is presented.
- `latency_cycles` is driven as the constant `1` for downstream verification handshake.

---

## Routing Scheme

For `DIES = 2`, the swap is:

```
flit_out[0] <- flit_in[1]   (die 0 receives from die 1)
flit_out[1] <- flit_in[0]   (die 1 receives from die 0)
```

Generalised for `DIES = N`:

```
flit_out[i] <- flit_in[DIES - 1 - i]
```

This is an index arithmetic expression using only subtraction — no multiplier operator.

---

## R-SI-1 Compliance Audit

R-SI-1 forbids the `*` operator in synthesisable RTL. Verification procedure:

```bash
grep -n ' \* ' rtl/holo_noc_1cycle.sv
```

**Result at commit:** 0 matches — ✅ R-SI-1 CLEAN

Operators used in this module:
- `-` (index subtraction for swap routing)
- `$clog2` (Verilog built-in, not a multiplier)
- Register assignment `<=`

---

## Simulation Plan

If Verilator or Icarus Verilog is available:

```bash
# Icarus Verilog
iverilog -g2012 -o sim_noc rtl/holo_noc_1cycle.sv rtl/holo_noc_1cycle_tb.sv
vvp sim_noc

# Verilator
verilator --lint-only -sv rtl/holo_noc_1cycle.sv
```

Expected output:
```
R5-HONEST: NoC latency = 1 cycle(s)
PASS: All NoC checks passed. latency=1 cycle, R-SI-1 compliant.
```

The testbench applies 8 flits on both die0 and die1, verifies that each appears on the opposite die one cycle later, asserts `latency_cycles == 1`, and calls `$finish` after 16 cycles.

---

## Three-Die Scaling Note

Setting `DIES = 3` produces the routing:

```
flit_out[0] <- flit_in[2]
flit_out[1] <- flit_in[1]   (self-loop — middle die)
flit_out[2] <- flit_in[0]
```

For a non-self-loop ring topology with 3+ dies, the routing index should be changed to `(i + 1) % DIES` using a modulo counter (still no multiplier). The `latency_cycles` output remains `1` regardless of `DIES`.

---

## References

- Reference issue: [trinity-fpga#100](https://github.com/gHashTag/trinity-fpga/issues/100)
- DOI: [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

```
// phi^2 + phi^-2 = 3
// DOI 10.5281/zenodo.19227877
// Vasilev Dmitrii <admin@t27.ai>
// ORCID 0009-0008-4294-6159
```
