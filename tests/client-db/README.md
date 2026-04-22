# Client DB fixtures (CES-37 / M0-02)

**Spec:** [`docs/specs/data-model.md`](../../docs/specs/data-model.md), [`docs/specs/si-units.md`](../../docs/specs/si-units.md)

## Purpose

Source-of-truth fixtures the client DB tests consume. Kept outside
`client/test/` so server-side tests (when M3 lands) can reuse the same
inputs and prove client ↔ server schema alignment without duplicating
canonical values.

## Layout

| File | Scenario |
|------|----------|
| [`fixtures/v0_empty.sql`](fixtures/v0_empty.sql) | Pre-M0 state: no tables — human-readable “empty DB” snapshot for review / future server tests. Dart DB tests use in-memory Drift directly (`client/test/db/`), not this file. |
| [`fixtures/v1_smoke.sql`](fixtures/v1_smoke.sql) | Hand-written minimal v1 snapshot: one vehicle, one fill-up, one draft. Exercised by the round-trip suite and acts as a human-readable reference of the expected SI-INT64 values. |
| [`fixtures/v1_v1_noop.sql`](fixtures/v1_v1_noop.sql) | Sentinel for "same schema version, no migration fires" — asserts the runner selects zero steps when `from == to`. |

## How the client consumes them

The Dart tests under [`client/test/db/`](../../client/test/db/) use
Drift's `NativeDatabase.memory()` executor and do **not** replay these
SQL files — those tests drive Drift's `MigrationStrategy` directly. The
SQL files in this directory are:

1. A **human-readable snapshot** of what a clean install (v0) and a
   first-run install (v1) look like — useful for PR review.
2. A **reuse surface** for the server migration tests (M3) so the same
   data values flow through `data-model.md`'s client ↔ server contract.

## Update rules

- Every new migration step (`0002_*`, `0003_*`) adds a matching
  `vN_smoke.sql` and updates `v1_v1_noop.sql` → `vN_vN_noop.sql`.
- Canonical units only (`volume_uL`, `odometer_m`, `total_price_cents`).
  No `DECIMAL`/`FLOAT` in fixtures — that's the whole point of
  `si-units.md`.
