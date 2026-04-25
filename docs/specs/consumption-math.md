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

### Segment status (normative)

Implementation: `client/lib/consumption/models.dart#SegmentStatus`. Every closed segment carries one of:

| Wire value                  | Meaning                                                                                                       |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `known`                     | Both endpoints `is_full = true`, same lineage, no `missed_before` in the inclusive set, `D > 0`.              |
| `unknown_missed`            | Any fill-up in the inclusive closing set has `missed_before = true`. Excluded from lifetime numerator + denominator. |
| `unknown_reset_boundary`    | Defensive: closing-full odometer < opening-full odometer with no `odometer_reset` flag. Validation should block this in v1; the status exists so invariants are observable rather than silent. |
| `degenerate_zero_distance`  | Two full fill-ups at the same odometer (`D == 0`). Surfaced to UX so the user can fix the entry.              |

Only `known` segments contribute to lifetime / windowed L/100km. `cents_per_km_tenths` is emitted for every status with `distance_m > 0` (UX may choose to hide it for non-`known`); `l_per_100km_tenths` is null for non-`known`.

### Formulas (integer-safe)

Throughout, let `V = segment_volume_uL`, `D = segment_distance_m`. Require `D > 0`; if `D == 0` a segment is degenerate (two full fill-ups at the same odometer — user error; flag as unknown and surface in UX).

**L/100 km (display):**
Mathematically: `(V / 1e6 L) / (D / 1e3 km) * 100 = V * 100 000 / (D * 1e6) = V / (D * 10)` in L/100km. We want a **tenths-of-L/100km integer**, which simplifies to `V / D` (the `× 10` for tenths and the `× 10` in the denominator cancel):

```
l_per_100km_tenths = divideRoundHalfEven(V, D)
```

Implementation: `client/lib/consumption/rounding.dart#divideRoundHalfEven` (banker's rounding / round-half-to-even at the integer division step). Pinned by fixtures `14_rounding_l_per_100km_tie_even.json` and `15_rounding_l_per_100km_tie_odd.json` in `tests/math/fixtures/`.

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
cents_per_km_tenths = divideRoundHalfEven(cost_cents * 10_000, D)   # meters → km via * 1000, then × 10 for tenths
```

Pinned by fixture `16_rounding_cents_per_km_tie.json`.

### Aggregation rules

- **Vehicle lifetime consumption** = sum of all known-segment `V` divided by sum of all known-segment `D`, expressed via the same `l_per_100km_tenths` formula. Unknown / degenerate segments are excluded from both numerator and denominator.
- **Lifetime total spend** = sum of `total_price_cents` across **every** non-soft-deleted fill-up for the vehicle, keyed by `currency_code`. Partials outside any closed segment, leading / trailing tails, and rows in unknown segments all contribute. Rationale: surfaces like "total spend" must not silently hide money that the user actually paid.
- **Trailing 12-month consumption** = same as lifetime L/100km but windowed by `filled_at` of the segment's closing fill-up.
- **Per-segment cost (`cost_cents`):** within a closed segment, only fill-ups whose `currency_code` matches the **closing-full's** currency contribute to `cost_cents` (and therefore `cents_per_km_tenths`). Partials in another currency drop out of segment cost but still appear in `price_history_by_currency` under their own key. The wider question of multi-currency cost normalisation is tracked in **CES-51**.
- **Price history** = scatter of `total_price_cents * 10_000_000 / volume_uL` in **cents-per-litre-tenths**, grouped per vehicle, keyed by `currency_code`. Implementation: `client/lib/consumption/price_history.dart#computePriceHistory`. Fill-ups with `volume_uL == 0` are excluded (no price-per-volume defined). If currencies vary, the result map carries one entry per currency; chart surfaces render one series per key and document the split in the legend.

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

Living set under [`tests/math/fixtures/`](../../tests/math/fixtures/) (kept outside `client/test/` so server-side ports under M3 can reuse the same canonical inputs without duplicating values). Twenty fixtures ship for the Stage 3 exit, grouped as:

**Spec-derived (1–8):** the original eight from the §"Golden test fixtures" table — `normal_full_to_full`, `partial_in_between`, `two_partials_plus_full`, `missed_fill_marks_unknown`, `regression_blocked`, `reset_accepted`, `first_fill_only`, `partials_only`.

**Validation rejection coverage (9–13):** one fixture per remaining `ValidationErrorCode` so every wire code (`ODOMETER_NEGATIVE`, `VOLUME_NEGATIVE`, `PRICE_NEGATIVE`, `FILLED_AT_IN_FUTURE`, `RESET_ON_FIRST_FILLUP`) has an executable contract test that the server (M3) and any future port can replay.

**Banker's rounding (14–16):** pin `divideRoundHalfEven` behaviour on `l_per_100km_tenths` (tie-even, tie-odd) and `cents_per_km_tenths`.

**Defensive segment statuses (17–18):** `degenerate_zero_distance` (two fulls at the same odometer) and `unknown_reset_boundary` (closing-full odometer < opening-full with no reset flag).

**Multi-currency + mixed lifetime (19–20):** `multi_currency` exercises the closing-currency cost-aggregation rule and multi-key `total_spend_cents_by_currency`; `mixed_known_unknown` confirms lifetime math sees only `known` segments while spend still sums everything.

The runner ([`client/test/consumption/fixture_runner_test.dart`](../../client/test/consumption/fixture_runner_test.dart)) auto-discovers every `*.json` and dispatches on `expected.kind` (`segments` or `validation_rejection`); see [`tests/math/README.md`](../../tests/math/README.md) for the full file inventory and JSON schema. Adding a fixture is a one-file change — drop a numbered `NN_short_name.json` in the fixtures dir and the runner picks it up.

Module purity invariant ("no Drift / no Flutter outside `adapters.dart`") is enforced at test time by [`client/test/consumption/module_purity_test.dart`](../../client/test/consumption/module_purity_test.dart). CI fixture coverage: both `verify-fast.yml` (default) and `verify-full.yml` trigger on `tests/math/**` so fixture-only PRs cannot bypass the matrix.

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
