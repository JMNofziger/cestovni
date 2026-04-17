# Spec: Consumption math & fill-up lifecycle

**Status:** Complete (v1)
**Linear:** CES-26
**Depends on:** [`si-units.md`](si-units.md) (canonical storage), [`data-model.md`](data-model.md) (concrete columns)

## Purpose

Define the exact math used for trip consumption, the fill-up flags that drive it, and the acceptance fixtures that prove it. This spec is the single source of truth for numbers shown on the Hero Economy, Trends, and Price History surfaces.

## Numeric foundation

All math runs on canonical SI integers from [`si-units.md`](si-units.md):

- `odometer_m` — INT64 meters
- `volume_uL` — INT64 microliters
- `total_price_cents` — INT64 cents (+ `currency_code`)
- All intermediate math stays integer; **rounding happens only at the display boundary** (see "Rounding" below).

## Fill-up model

### Required fields

| Field               | Type                       | Meaning                                                      |
| ------------------- | -------------------------- | ------------------------------------------------------------ |
| `id`                | UUID                       | Stable row id (client-generated; see ADR 002).               |
| `vehicle_id`        | UUID                       | Which vehicle.                                                |
| `filled_at`         | TIMESTAMPTZ                | When the fuel went in (user-provided; default now UTC).       |
| `odometer_m`        | BIGINT                     | Odometer at the pump (canonical).                             |
| `volume_uL`         | BIGINT                     | Dispensed volume (canonical).                                 |
| `total_price_cents` | BIGINT                     | Receipt total (canonical).                                    |
| `currency_code`     | CHAR(3)                    | ISO 4217 for the receipt.                                     |
| `is_full`           | BOOLEAN                    | Did the user fill to "click-off" / brim? (see flags below).   |
| `missed_before`     | BOOLEAN                    | Is this entry known to have an earlier fill-up not recorded?  |
| `odometer_reset`    | BOOLEAN                    | Does this entry restart the odometer segment? (see below).    |
| `notes`             | TEXT NULL                  | Free text; excluded from math.                                |

### Flags — semantics

- **`is_full = true`** — the tank was filled to a consistent click-off level. Only full fill-ups **close** a consumption segment.
- **`is_full = false`** — a partial fill; contributes volume to the open segment but does not close it.
- **`missed_before = true`** — the user knows at least one fill-up between this entry and the previous recorded one was not logged. The segment that contains a `missed_before=true` fill-up is marked **unknown** (volume cannot be trusted as the total poured into the vehicle for that segment).
- **`odometer_reset = true`** — set by the user when the odometer itself has been reset/replaced (e.g. cluster swap, ECU reflash). This fill-up's `odometer_m` is treated as a new segment origin; the segment that ended at this reset is closed as **unknown**.

### Validation rules at entry

Enforced **on the client** before the row is enqueued to the outbox, and **on the server** before the mutation is accepted:

1. `odometer_m >= 0`, `volume_uL >= 0`, `total_price_cents >= 0` (CHECKs in schema too; see [`data-model.md`](data-model.md)).
2. `filled_at` is not in the future (tolerance: user's local clock + 24 h to account for timezone slop).
3. **Odometer regression rule:** let `prev` be the most recent fill-up for this vehicle **with the same `odometer_reset = false` lineage** (i.e. no reset between them). If `odometer_m < prev.odometer_m`, the mutation is **rejected** unless `odometer_reset = true` on the new entry.
   - Client UX: inline error + "Mark as odometer reset?" affordance. The user must explicitly confirm the reset; we do not auto-fix.
   - Server: same predicate is enforced server-side for defense in depth (a buggy client must not pollute history).
4. A fill-up **cannot** be both `odometer_reset = true` **and** the very first fill-up for a vehicle (there's nothing to reset from); reject with clear error.

## Consumption segment model

A **segment** is a span of driving between two `is_full = true` fill-ups that belong to the same odometer lineage. The distance and fuel used in that span are computable; anything else is "unknown".

### Formal definition

Given fill-ups for one vehicle, ordered by `(filled_at ASC, id ASC)` as a stable tie-breaker:

1. Partition the list at every `odometer_reset = true` row. Each partition is an **odometer lineage**.
2. Within a lineage, walk forward and define segments as `(prev_full, next_full]` where both endpoints have `is_full = true`. The half-open interval means:
   - `segment_distance_m = next_full.odometer_m - prev_full.odometer_m`
   - `segment_volume_uL = SUM(volume_uL) for all fill-ups f where prev_full.filled_at < f.filled_at <= next_full.filled_at` (this includes `next_full` itself and any partial fill-ups strictly between).
3. A segment is **unknown** (excluded from trends) if **any** fill-up in the inclusive set `[prev_full exclusive, next_full inclusive]` has `missed_before = true`.
4. A lineage's **leading partial tail** (partials before the first full fill-up) contributes nothing; a lineage's **trailing partial tail** (partials after the last full fill-up) contributes nothing until another full fill-up closes them.

### Formulas (integer-safe)

Throughout, let `V = segment_volume_uL`, `D = segment_distance_m`. Require `D > 0`; if `D == 0` a segment is degenerate (two full fill-ups at the same odometer — user error; flag as unknown and surface in UX).

**L/100 km (display):**
Mathematically: `(V / 1e6 L) / (D / 1e3 km) * 100 = V * 100 000 / (D * 1e6) = V / (D * 10)` in L/100km — but we want a **tenths-of-L/100km integer** for rounding:

```
l_per_100km_tenths = (V * 10 + D * 5) / (D * 10)
```

Where `+ D*5` is integer half-round-to-nearest. (Banker's rounding variant in code: split the exact remainder path; see `tests/math/` fixtures.)

Display as `l_per_100km_tenths / 10` with 1 decimal.

**MPG (US, display):**
`MPG = miles / US_gal = (D / 1609.344) / (V / 3_785_411_784)`.

Integer-safe derivation:

```
mpg_tenths = (D * 3_785_411_784 * 10 + V * 1_609_344 / 2) / (V * 1_609_344_000)
```

Equivalently, convert the L/100km result to MPG with the exact identity `MPG = 235.2145833... / (L/100km)` only for display sanity checks, never as primary math (introduces a truncation).

**Cost per distance (display):**

```
cents_per_km_tenths = (cost_cents * 10 000 + D / 2) / D   # using meters → km via * 1000
```

### Aggregation rules

- **Vehicle lifetime consumption** = sum of all known-segment `V` divided by sum of all known-segment `D`, expressed via the same `l_per_100km_tenths` formula. Unknown segments are excluded from both numerator and denominator.
- **Trailing 12-month consumption** = same as above but windowed by `filled_at` of the segment's closing fill-up.
- **Price history** = scatter of `total_price_cents * 1_000_000 / volume_uL` (cents-per-liter-of-fuel), grouped per vehicle, filtered by currency. If currencies vary, surface a warning and drop out-of-currency entries from the chart.

## Rounding policy

| Context                       | Rule                                                               |
| ----------------------------- | ------------------------------------------------------------------ |
| Internal math                 | Integer arithmetic end-to-end; no float until display.             |
| Intermediate division         | Banker's rounding (round-half-to-even) at the final division step. |
| Display `L/100 km`, `MPG`     | 1 decimal.                                                         |
| Display `cents/km`            | 2 decimals (major currency).                                       |
| CSV                           | Canonical integer **plus** 2-decimal converted column (see [`si-units.md`](si-units.md)). |
| Charts vs CSV                 | Same canonical inputs; CSV exposes both canonical + display; chart axis rounding documented in `README_export.txt`. |

Multi-currency: if a vehicle has fill-ups in more than one currency, trend and price-history charts render **one line per currency** and document the split in the legend; CSV always carries `currency_code` per row.

## Fill-up lifecycle (interacts with sync)

This section aligns with the lifecycle in [`sync-protocol.md`](sync-protocol.md):

| State          | Source                                                              | Outbox? |
| -------------- | ------------------------------------------------------------------- | ------- |
| `draft`        | User snapped a receipt or partially filled the form.                | No      |
| `complete`     | All required fields are present; validation passes.                 | Yes, `op=insert` |
| `amended`      | User edits a complete fill-up.                                      | Yes, `op=update` |
| `soft_delete`  | User removes a fill-up.                                             | Yes, `op=soft_delete` |

Math operates only on `complete` (non-soft-deleted) rows. Drafts are invisible to consumption math and to export.

## Golden test fixtures (acceptance)

Landing alongside the code in `tests/consumption/fixtures/`. Each fixture is a list of fill-ups + expected segment outcomes. Eight fixtures are required for Stage 3 exit:

| # | Fixture name                     | Shape                                                                              | Expected outcome                                                                                      |
| - | -------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 1 | `normal_full_to_full`            | 2 full fill-ups, 1 000 km apart, 50 L consumed.                                    | 1 segment; `5.0 L/100km`.                                                                             |
| 2 | `partial_in_between`             | Full @ 0 km, partial @ 500 km (20 L), full @ 1 000 km (30 L).                      | 1 segment; `V = 50 L`, `D = 1 000 km`; `5.0 L/100km`.                                                 |
| 3 | `two_partials_plus_full`         | Full @ 0, partial @ 300 (10 L), partial @ 600 (10 L), full @ 1 000 (30 L).         | 1 segment; `V = 50 L`, `D = 1 000 km`; `5.0 L/100km`.                                                 |
| 4 | `missed_fill_marks_unknown`      | Full @ 0, full @ 1 000 (30 L) with `missed_before=true`.                           | 1 segment, flagged **unknown**; excluded from trends; lifetime math treats as absent.                  |
| 5 | `regression_blocked`             | Full @ 1 000, then attempt to insert full @ 900 **without** `odometer_reset`.      | **Rejected** at client validation AND server; error surfaced with "Mark as odometer reset?" prompt.    |
| 6 | `reset_accepted`                 | Full @ 1 000 (20 L), then full @ 100 (25 L) with `odometer_reset=true`.            | 2 lineages; first has no closed segment (only 1 full); second starts fresh; no unknown segment leaks. |
| 7 | `first_fill_only`                | Single full fill-up.                                                               | 0 segments; lifetime consumption is "—" (not zero).                                                    |
| 8 | `partials_only`                  | 3 partials, no full.                                                               | 0 segments; lifetime consumption is "—"; total spend still computes from `total_price_cents`.          |

Each fixture ships as a JSON file with an expected-output JSON next to it; the test runner is language-agnostic enough to be rerun under the chosen mobile stack.

## Non-goals (v1)

- **Fuel-quality / octane insights** — brief excludes from v1.
- **Per-trip consumption** (segment between arbitrary odometer points without a full fill-up anchor) — v1.x.
- **Cross-currency price normalization** — out of scope; v1 shows one series per currency.
- **Tire/rotation-aware odometer correction** — UX spec territory, not math.

## Critical gaps / risks

- **Time zones for `filled_at`:** we store UTC; the user-facing date is derived from the user's timezone in `settings`. If a user crosses timezones, segment boundaries based on date may look off by a day; math uses odometer anchors, not dates, so the math itself is unaffected.
- **Clock skew:** `filled_at` is user-provided; the ordering used by math is `(filled_at ASC, id ASC)`. If two fill-ups share a `filled_at` to the second, `id` ordering is stable but may not match the user's intuition. Not a math correctness problem; possibly a UX one.
- **Vehicle archive vs math:** archived vehicles keep their fill-ups; math still runs on them for historical display.

## References

- [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) — risks section (consumption math is risk #1).
- [`si-units.md`](si-units.md) — canonical storage & rounding foundation.
- [`data-model.md`](data-model.md) — exact column definitions and constraints.
- [`sync-protocol.md`](sync-protocol.md) — fill-up lifecycle on the wire.
