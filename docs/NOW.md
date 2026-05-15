# NOW — Active Lane Status

**Quantum Brain HOLOGRAPHIC · tt-trinity-holo**  
**Anchor:** φ²+φ⁻²=3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## Sacred Opcode Range (ascending)

| Opcode | Lane | Module | Status |
|--------|------|--------|--------|
| `0xDE` | Lane C' | Load Physical Constants | Merged |
| `0xDF` | Lane V  | (predecessor) | Merged |
| `0xE0` | **Lane W** | `holo_bitrom_bank` — BitROM weight bank | **Active — Wave-28** |

---

## Lane W — BitROM Weight Bank (OP_BITROM_READ 0xE0)

**Wave:** L-DPC25 Wave-28  
**Branch:** `feat/lane-w-bitrom-bank`  
**Tracking issue:** [tt-trinity-holo#18](https://github.com/gHashTag/tt-trinity-holo/issues/18)

### What was delivered

| File | Lines | Description |
|------|-------|-------------|
| `rtl/holo_bitrom_bank.sv` | 110 | BitROM bidirectional weight bank, R-SI-1 clean |
| `rtl/holo_bitrom_bank_tb.sv` | 177 | Testbench — fwd/rev direction, 1-cycle latency |
| `docs/L_DPC25_LANE_W_BITROM.md` | 110 | Citation, pre-registration, falsification record |
| `docs/NOW.md` | this file | Lane status update |

### Key properties

- **Opcode:** `0xE0` (R15: continues after `0xDF` Lane V, `0xDE` Lane C')
- **ROM pattern:** `rom[i] = i ^ 8'h5A` — XOR only, zero `*` operators (R-SI-1)
- **Latency:** 1 clock cycle
- **Bidirectional:** `direction=0` → `rom[addr]`; `direction=1` → `rom[255-addr]`
- **Parameters:** `ROM_DEPTH=256`, `WORD_WIDTH=8`, `ADDR_WIDTH=8`
- **Energy claim:** 20.8 TOPS/W @ 65 nm ([arXiv 2509.08542](https://arxiv.org/abs/2509.08542)) — R5-HONEST: pre-registered, not yet measured on TTIHP27a
- **Spec witness:** `bitrom_no_star` lemma in `coq/IGLA/RMarker.v` (t27 PR #637, `5758b53c`)
- **R18 LAYER-FROZEN:** No existing `holo_*.sv` touched

### Anti-`*` status

```
grep -n '\*' rtl/holo_bitrom_bank.sv  →  0 matches in synthesisable blocks
```

R-SI-1 **PASS**

### Pre-registration

**H-W:** "BitROM BER ≤ 1e-9 on TTIHP27a"  
Falsified if: BER > 1e-9 OR `rtl_uses_star=true` OR latency > 1 cycle OR reverse ≠ mirror of forward.

---

*Last updated: Lane W Wave-28 · φ²+φ⁻²=3*
