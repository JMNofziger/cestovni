# Spec: SI canonical storage & US liquid gallon

**Status:** Complete (v1)
**Linear:** CES-27
**Depends on:** none — foundational; consumed by [`consumption-math.md`](consumption-math.md), [`data-model.md`](data-model.md), [`export-v1.md`](export-v1.md)

## Purpose

One place that defines **how physical quantities are stored, converted, rounded, and exported** across the product. Every other spec that touches numbers MUST reference this one.

## Storage convention (canonical)

All physical quantities live in the database as **signed 64-bit integers** with fixed scale. No `DECIMAL`, no `FLOAT`, no `NUMERIC`. This applies equally to the server Postgres schema and the client SQLite schema.

| Quantity         | Canonical column type | Unit                        | Notes                                                |
| ---------------- | --------------------- | --------------------------- | ---------------------------------------------------- |
| Volume (fuel)    | `BIGINT`              | **microliters (µL)**        | `1 L = 1 000 000 µL`                                 |
| Distance         | `BIGINT`              | **meters (m)**              | `1 km = 1 000 m`                                     |
| Money (amount)   | `BIGINT`              | **cents of currency**       | Scale always 1/100; see "currency scale" note below  |
| Currency code    | `CHAR(3)`             | ISO 4217                    | Paired with every money column                       |
| Timestamps       | `TIMESTAMPTZ`         | UTC                         | Display timezone is a user setting (see `settings`)  |

### Rules

1. **Do not store derived physical quantities.** `price_per_liter`, `L/100km`, `MPG`, etc. are **display-only**; compute from the canonical columns at render time.
2. **Do not store user-preferred units.** The user's unit preference lives in `settings` and affects only UI rendering and CSV "derived" columns on export.
3. **NOT NULL unless explicitly nullable in the domain spec.** Zero is a legal value (e.g. a 0-cost maintenance event); NULL means "not recorded".
4. **Non-negative CHECK constraints** on all canonical physical columns (`volume_uL >= 0`, `odometer_m >= 0`, `total_price_cents >= 0`). Distance deltas may be negative in math (odometer regression) but stored odometer values never are.
5. **INT64 overflow headroom.** Max `BIGINT` = ~9.22e18. For context: a 100 L fill-up = `1e8` µL; a 2 000 000 km odometer = `2e9` m; a $1 000 000 total = `1e8` cents. All four orders of magnitude below INT64 — no practical risk.

### Currency scale note

v1 assumes every supported currency has a 2-decimal minor unit (cents/pence/centimes). Currencies with different scales (JPY 0-decimal, BHD 3-decimal) are out of scope for v1 and flagged in [`data-model.md`](data-model.md) as a revisit gate. If added later, scale lookup becomes a column on `settings` rather than a canonical change.

## Entry units (what the user types)

The user may enter values in any of these units. The app converts to canonical at save time.

| Quantity | Allowed entry units              | Converts to | Exact conversion constant                     |
| -------- | -------------------------------- | ----------- | --------------------------------------------- |
| Volume   | liter (L), US liquid gallon (gal) | µL          | `1 L = 1 000 000 µL` <br> `1 US gal = 3 785 411 784 µL` (exact — 3.785411784 L × 10⁶) |
| Distance | kilometer (km), mile (mi)        | m           | `1 km = 1 000 m` <br> `1 mi = 1 609.344 m` (exact) |
| Money    | major currency unit              | cents       | `1.00 USD = 100 cents`                        |

### Entry rounding rule

Convert the user's entry to canonical with **banker's rounding** (round-half-to-even) at the nearest canonical unit. Examples:

- `42.183 L` → `42 183 000` µL (no rounding; exact)
- `13.157 gal` → `13.157 × 3 785 411 784 = 49 807 362 871.288` → rounds to **`49 807 362 871`** µL
- `123.456 mi` → `123.456 × 1 609.344 = 198 689.195...` → rounds to **`198 689`** m
- `45.678 km` → `45 678` m
- `€ 67.89` → `6 789` cents

### Why banker's rounding

Avoids cumulative upward bias when many round-half cases stack (common with gallon entries). Unit test: sum of 1000 × `0.5 µL`-equivalent ties must round to the same integer regardless of order.

## Display conversion rules

When rendering a canonical value back to the user:

| Display context         | Format rule                                                                    |
| ----------------------- | ------------------------------------------------------------------------------ |
| Volume in lists         | Convert to preferred unit; show to **2 decimals** (`42.18 L`, `13.16 gal`)    |
| Distance in lists       | Convert to preferred unit; show to **0 decimals** (`12 345 km`, `7 668 mi`)   |
| Consumption (L/100km)   | **1 decimal** (`7.2 L/100km`)                                                  |
| Consumption (MPG)       | **1 decimal** (`32.5 MPG`)                                                     |
| Price per unit          | **2 decimals** in major currency (`€ 1.38 / L`, `$ 3.46 / gal`)               |
| Totals                  | **2 decimals** in major currency                                               |
| Chart ticks             | Match the rendering column's rule above                                        |

All rounding at display is **banker's rounding** too, for consistency with entry.

## CSV / export contract

Every CSV exported from the app (see [`export-v1.md`](export-v1.md)) uses a **two-column pattern** for every physical quantity:

1. **Canonical column** — raw integer in canonical units. Column name ends in the canonical unit, e.g. `volume_uL`, `odometer_m`, `total_price_cents`.
2. **Derived column** — human-readable converted value in the user's preferred unit at export time. Column name ends in the display unit, e.g. `volume_L`, `odometer_km`, `total_price_major`.

### Example header for `fill_ups.csv`

```csv
id,vehicle_id,filled_at_utc,odometer_m,odometer_km,volume_uL,volume_L,total_price_cents,total_price_major,currency_code,is_full,missed_before,odometer_reset,notes
```

### Rules

- The canonical column is the **source of truth**. Derived columns exist for user convenience (spreadsheet review); re-import MUST use canonical columns only.
- Derived columns follow the same rounding as display (2 decimals volume, 0 decimals distance, etc.) and note the rule in `README_export.txt`.
- Timestamps in CSV are ISO-8601 in **UTC** with a `_utc` suffix on the column name; a parallel `_local` column uses the user's timezone when exporting, labeled clearly.

## Non-goals (v1)

- **Temperature** (ambient, fuel) is not stored in v1. If added, canonical will be **deci-°C** (INT64) following the same pattern.
- **Pressure** (tire) is deferred to UX spec; canonical TBD if added.
- **Multi-currency per user** is deferred; one `currency_code` per user in `settings`.

## Test expectations

Landing alongside this spec in `tests/units/`:

1. **Round-trip** tests per entry unit: `value → canonical → display → value` must equal the original input (modulo documented display rounding).
2. **Banker's rounding** tests: all 1-tie-per-value pairs must tie to even at the nearest canonical unit.
3. **Bulk summation** test: sum of 10 000 fixture fill-ups computed with integer math vs naive `double` must diverge — documenting why we refuse `DECIMAL`/`FLOAT`.
4. **Overflow headroom** test: synthetic "absurd" values (10 000 L fill-up, 10 000 000 km odometer, $10 000 000 price) must not overflow INT64.

## References

- [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) — locked decisions: SI canonical, US liquid gallon.
- [`consumption-math.md`](consumption-math.md) — uses the formulas and rounding rules here.
- [`data-model.md`](data-model.md) — applies these types to concrete columns.
- [`export-v1.md`](export-v1.md) — applies the CSV contract above.
