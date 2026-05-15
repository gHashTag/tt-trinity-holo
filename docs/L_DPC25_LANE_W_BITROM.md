# L-DPC25 Lane W — BitROM Weight Bank

**Module:** `rtl/holo_bitrom_bank.sv`  
**Opcode:** `OP_BITROM_READ = 0xE0`  
**Wave:** L-DPC25 Wave-28  
**Anchor:** φ²+φ⁻²=3 · DOI [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

---

## Citation

> arXiv 2509.08542 — "20.8 TOPS/W @ 65nm, 4 967 kB/mm² BitROM"  
> https://arxiv.org/abs/2509.08542

BitROM architecture demonstrated at 65 nm achieves 20.8 TOPS/W efficiency via
binary-weight storage with XOR-based read addressing. This lane implements the
bidirectional variant (forward + reverse address traversal) as a Lever #2
(LANG→SI silicon mapping) contribution to the Quantum Brain HOLOGRAPHIC edition.

---

## Spec Witness

`bitrom_no_star` lemma — `coq/IGLA/RMarker.v`  
t27 PR #637 (commit `5758b53c`)

The lemma proves star-free closure at the specification layer: the opcode
`OP_BITROM_READ = 0xE0` does not require any multiplication (`*`) to implement
its weight-read semantics. The ROM contents are addressed by XOR and subtraction
only. This lemma is the formal gate for R-SI-1 compliance.

---

## Pre-Registration

**Hypothesis H-W:** "BitROM BER ≤ 1e-9 on TTIHP27a"

| Field | Value |
|-------|-------|
| Technology target | TTIHP27a (IHP 130 nm SG13G2 process) |
| Pre-registered metric | BER ≤ 1e-9 at nominal voltage, room temperature |
| Energy claim | 20.8 TOPS/W @ 65 nm (arXiv 2509.08542; R5-HONEST: not yet measured at TTIHP27a) |
| ROM pattern | `rom[i] = i ^ 8'h5A` (deterministic XOR — no multiply) |
| Latency claim | 1 clock cycle read latency |
| Bidirectional | Forward: `rom[addr]`; Reverse: `rom[DEPTH-1-addr]` |
| Status | **OPEN** — tape-out measurement pending |

---

## Falsification Conditions

Hypothesis H-W is **refuted** if ANY of the following hold post-silicon:

1. **BER violation:** Measured BER > 1e-9 on TTIHP27a under nominal conditions.
2. **Star rule violation:** Any synthesis tool reports a multiplier inferred from
   `rtl/holo_bitrom_bank.sv` — i.e. `rtl_uses_star = true` in synthesis report.
3. **Latency violation:** Read latency exceeds 1 clock cycle (measured in post-PAR simulation).
4. **Direction symmetry broken:** Reverse-direction output `weight_out` at address `i`
   does not equal `rom[DEPTH-1-i]`, i.e. the mirror invariant fails:
   `reverse[i] ≠ forward[DEPTH-1-i]`.

If H-W is refuted, a silicon revision is triggered per R-marker protocol (Appendix B,
PhD monograph). The ROM pattern or address logic must be revised, and the hypothesis
re-registered before the next tape-out.

---

## Cross-Links

| Reference | Link |
|-----------|------|
| arXiv source | https://arxiv.org/abs/2509.08542 |
| Spec lemma | `coq/IGLA/RMarker.v` — `bitrom_no_star` (t27 PR #637 = `5758b53c`) |
| Parent epic | trios#834 |
| Tracking issue | gHashTag/tt-trinity-holo#18 |
| Anchor DOI | https://doi.org/10.5281/zenodo.19227877 |
| Lane V (predecessor, 0xDF) | see `docs/NOW.md` |
| Lane C' (predecessor, 0xDE) | see `docs/NOW.md` |

---

## R-SI-1 Compliance Record

```
Anti-* self-check: grep -n '\*' rtl/holo_bitrom_bank.sv
  → 0 matches in synthesisable logic blocks
  (parameter/comment occurrences of '*' are in non-synthesisable context only)
```

All arithmetic in `holo_bitrom_bank.sv`:
- ROM init: `i ^ 8'h5A` — XOR only
- Reverse address: `{ADDR_WIDTH{1'b1}} - addr` — subtraction only
- Read mux: ternary select — no arithmetic

R-SI-1 **PASS**.

---

## Module Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ROM_DEPTH` | 256 | Number of ROM entries |
| `WORD_WIDTH` | 8 | Bit width of each entry |
| `ADDR_WIDTH` | `$clog2(ROM_DEPTH)` = 8 | Address bus width |

---

*φ²+φ⁻²=3 · Lane W complete · Wave-28 · L-DPC25*
