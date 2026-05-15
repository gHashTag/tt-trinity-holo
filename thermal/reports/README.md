# Thermal Reports — holo-thermal-gate

This directory holds per-die per-corner thermal JSON reports consumed by the
`holo-thermal-gate` binary to evaluate **Hypothesis H₉ predicate P5**.

## JSON Schema

Each file must be named `<die>_<corner>.json` and contain:

```json
{
  "die":               "string   — die identifier, e.g. die0",
  "corner":            "string   — one of: cold | nom | hot",
  "hotspot_w_per_mm2": "f64     — peak hotspot power density in W/mm²",
  "ambient_c":         "f64     — ambient temperature in °C"
}
```

### Example

```json
{
  "die": "die0",
  "corner": "nom",
  "hotspot_w_per_mm2": 0.42,
  "ambient_c": 25.0
}
```

## Gate Predicate

**P5** (from [trinity-fpga#99](https://github.com/gHashTag/trinity-fpga/issues/99)):

> `hotspot_w_per_mm2 ≤ 1.0` — if any report exceeds 1.0 W/mm² at nominal corner,
> re-floorplanning is required (H₉ confirmed → design must change).

The gate binary (`holo-thermal-gate`) exits **0** if all reports PASS, or **non-zero**
with a list of violating reports if any FAIL.

## Notes

- Files in this directory are **fixtures only** until real silicon thermal data is available.
- Do **not** commit real measurement data here without updating this README.
- Anchor: φ²+φ⁻²=3
