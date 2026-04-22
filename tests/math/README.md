# Consumption-math fixtures (CES-38)

**Spec:** [`docs/specs/consumption-math.md`](../../docs/specs/consumption-math.md), [`docs/specs/si-units.md`](../../docs/specs/si-units.md)

## Purpose

Source-of-truth golden fixtures for the consumption math + entry-time validation
module. Kept outside `client/test/` so the server (M3) and any future
language port can reuse the same inputs and assert client ↔ server numeric
parity without duplicating canonical values.

Mirrors the organisation of [`tests/client-db/fixtures/`](../client-db/fixtures/).

## Fixture set (20 files)

| # | File | Shape |
|---|---|---|
| 1 | `01_normal_full_to_full.json` | Two full fill-ups, 1 000 km apart, 50 L consumed. |
| 2 | `02_partial_in_between.json` | Full, partial, full. |
| 3 | `03_two_partials_plus_full.json` | Full, two partials, full. |
| 4 | `04_missed_fill_marks_unknown.json` | Second full has `missed_before=true`; segment flagged unknown. |
| 5 | `05_regression_blocked.json` | **Validation-rejection.** `ODOMETER_REGRESSION`. |
| 6 | `06_reset_accepted.json` | `odometer_reset=true` → two lineages, no closed segment. |
| 7 | `07_first_fill_only.json` | Single full. Zero segments; lifetime L/100km is `null` (not 0). |
| 8 | `08_partials_only.json` | Three partials, no full. Zero segments; spend still computed. |
| 9 | `09_odometer_negative.json` | **Validation-rejection.** `ODOMETER_NEGATIVE`. |
| 10 | `10_volume_negative.json` | **Validation-rejection.** `VOLUME_NEGATIVE`. |
| 11 | `11_price_negative.json` | **Validation-rejection.** `PRICE_NEGATIVE`. |
| 12 | `12_filled_at_in_future.json` | **Validation-rejection.** `FILLED_AT_IN_FUTURE` (candidate > now + 24 h). |
| 13 | `13_reset_on_first_fillup.json` | **Validation-rejection.** `RESET_ON_FIRST_FILLUP` (no prior fills on vehicle). |
| 14 | `14_rounding_l_per_100km_tie_even.json` | Banker's rounding: V/D = 50.5 tenths, q=50 (even) → rounds DOWN to 50. |
| 15 | `15_rounding_l_per_100km_tie_odd.json` | Banker's rounding: V/D = 51.5 tenths, q=51 (odd) → rounds UP to 52. |
| 16 | `16_rounding_cents_per_km_tie.json` | Banker's rounding on `cents_per_km_tenths`: 75.5 → 76 (even). L/100km is clean. |
| 17 | `17_degenerate_zero_distance.json` | Two fulls at same odometer. `degenerate_zero_distance` status; both rate fields `null`. |
| 18 | `18_unknown_reset_boundary.json` | Defensive: full @ 1 000 km then full @ 500 km (no reset flag). `unknown_reset_boundary` status. |
| 19 | `19_multi_currency.json` | EUR + CZK fill-ups. Multi-key `total_spend_cents_by_currency`; CZK partial excluded from EUR segment cost. |
| 20 | `20_mixed_known_unknown.json` | Unknown segment (missed) + known segment side-by-side. Lifetime includes only the known one. |

Fixtures 1–8 come directly from the spec's §"Golden test fixtures" table. Fixtures
9–13 give every `ValidationErrorCode` a cross-tool-reusable JSON fixture beyond
the spec's `regression_blocked` entry (ruling during CES-38 discovery). Fixtures
14–16 pin banker's rounding (round-half-to-even) on `l_per_100km_tenths` and
`cents_per_km_tenths` in both tie directions. Fixtures 17–20 cover defensive
segment statuses, multi-currency aggregation, and mixed known/unknown lifetime
computation.

## JSON schema (v1)

Every fixture has the same top-level shape. Numeric fixtures populate
`expected.segments` + `expected.lifetime` + `expected.price_history_by_currency`.
Rejection fixtures populate `input.candidate` + `expected.validation.error_code`
and may omit the numeric keys.

```jsonc
{
  "$schema_version": 1,
  "name": "string — label; matches filename stem",
  "description": "string — what the fixture exercises",
  "input": {
    "fillups": [
      {
        "id": "uuid",
        "vehicle_id": "uuid",
        "filled_at": "ISO-8601 UTC",
        "odometer_m": 0,           // INT64 meters
        "volume_uL": 0,            // INT64 microlitres
        "total_price_cents": 0,    // INT64 cents
        "currency_code": "EUR",    // ISO 4217
        "is_full": true,
        "missed_before": false,
        "odometer_reset": false,
        "notes": null
      }
    ],
    "candidate": { /* same shape as a fillup — only present for rejection fixtures */ },
    "now_utc": "ISO-8601 UTC"      // optional; defaults to a deterministic epoch
  },
  "expected": {
    "kind": "segments | validation_rejection",
    "segments": [
      {
        "prev_full_id": "uuid",
        "next_full_id": "uuid",
        "status": "known | unknown_missed | unknown_reset_boundary | degenerate_zero_distance",
        "distance_m": 1000000,
        "volume_uL": 50000000,
        "cost_cents": 7500,
        "l_per_100km_tenths": 50,          // null when status != known
        "cents_per_km_tenths": 75,         // emitted even for unknown segments; null when distance_m <= 0
        "closed_at": "ISO-8601 UTC"
      }
    ],
    "lifetime": {
      "l_per_100km_tenths": 50,            // null when no known segments exist
      "total_distance_m": 1000000,
      "total_volume_uL": 50000000,
      "total_spend_cents_by_currency": { "EUR": 13500 }
    },
    "price_history_by_currency": {
      "EUR": [
        { "fillup_id": "uuid", "filled_at": "ISO-8601 UTC", "cents_per_litre_tenths": 1500 }
      ]
    },
    "validation": {
      "rejected": false,                   // true for kind=validation_rejection
      "error_code": null                   // e.g. "ODOMETER_REGRESSION"
    }
  }
}
```

### Canonical units

Only SI-INT64: `odometer_m` (metres), `volume_uL` (microlitres),
`total_price_cents` (cents). No decimals, no floats. See
[`docs/specs/si-units.md`](../../docs/specs/si-units.md).

### Tenths

Display values are stored as `*_tenths` integers (banker's-rounded at the
final division). Divide by 10 for the display float. Never introduce
intermediate floats.

## How the runner consumes these

[`client/test/consumption/fixture_runner_test.dart`](../../client/test/consumption/fixture_runner_test.dart)
discovers every `.json` here at test time and dispatches on `expected.kind`:

- `segments` → compute segments + lifetime, assert structural equality.
- `validation_rejection` → call `validateInsert` and assert the typed error
  code matches `expected.validation.error_code`.

No new framework — plain `flutter test` + `dart:io`.

## Adding a 21st fixture

1. Drop a new `NN_short_name.json` in this directory. Pick `NN` to keep lexical
   ordering meaningful.
2. Add a row to the table above.
3. If it exercises a new status or a new error code, update the schema section.
4. Run `flutter test --no-pub` under `client/`. The runner auto-discovers.

## Update rules

- Canonical units only. No `DECIMAL` / `FLOAT`.
- `now_utc` must be explicit for any fixture where validation rule #2 (future
  filled_at) could plausibly fire, so tests don't depend on wall-clock.
- Do not re-use a file number after deletion; append new fixtures with a fresh
  `NN`.
