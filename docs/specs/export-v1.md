# Spec: Export v1 (ZIP + CSV + manifest)

**Status:** Complete (v1)
**Linear:** CES-28
**Depends on:** [`si-units.md`](si-units.md) (canonical + derived columns), [`data-model.md`](data-model.md) (tables), [`photo-pipeline.md`](photo-pipeline.md) (photos excluded), [`sync-protocol.md`](sync-protocol.md) (outbox flush)

## Purpose

The user's full, portable copy of their structured history: a single ZIP they can share, inspect in a spreadsheet, or import into a different tool. Data portability is a product principle; this spec makes it testable.

## Scope

- **In:** structured data for the signed-in user — `vehicles`, `fill_ups`, `maintenance_rules`, `maintenance_events`, `settings`.
- **Out:** receipt photos (ephemeral, local; see [`photo-pipeline.md`](photo-pipeline.md)), drafts, outbox contents, client logs.

## Output layout

```
cestovni_export_<userkeyhash>_<timestamp>.zip
├── manifest.json
├── README_export.txt
├── vehicles.csv
├── fill_ups.csv
├── maintenance_rules.csv
├── maintenance_events.csv
└── settings.csv
```

- `<userkeyhash>` is the first 8 hex chars of the telemetry user key (not the raw user id; see [`telemetry-allowlist.md`](telemetry-allowlist.md)).
- `<timestamp>` is `YYYYMMDD_HHMMSS` in UTC.

## `manifest.json`

The canonical manifest. Every consumer (a later re-import tool, a test asserting export correctness, or a compliance auditor) reads from here first.

```json
{
  "schema_version": 1,
  "exported_at_utc": "2026-04-17T18:04:22Z",
  "app_version": "0.9.0",
  "app_platform": "ios",
  "timezone": "Europe/Prague",
  "user_key_hash": "9b3a5f01",
  "unit_preferences": {
    "distance": "km",
    "volume":   "L",
    "currency": "EUR"
  },
  "row_counts": {
    "vehicles": 3,
    "fill_ups": 812,
    "maintenance_rules": 12,
    "maintenance_events": 47,
    "settings": 1
  },
  "outbox_pending_count": 0,
  "outbox_pending_hash":  null,
  "photos_in_export": false,
  "max_row_version_seen": 1049
}
```

### Fields

| Field                  | Notes                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------ |
| `schema_version`       | Integer; bump on breaking changes. v1 = `1`.                                                     |
| `exported_at_utc`      | ISO-8601 UTC, second precision.                                                                  |
| `app_version`          | Semver string.                                                                                   |
| `app_platform`         | `ios` or `android`.                                                                              |
| `timezone`             | IANA name from `settings`. CSV `_local` columns use this.                                        |
| `user_key_hash`        | First 8 hex of telemetry user key; enough to disambiguate multiple exports, not enough to trace. |
| `unit_preferences`     | Echo of `settings` at export time; drives CSV derived columns and `README_export.txt`.           |
| `row_counts`           | Per-entity counts of exported rows (after `deleted_at IS NULL` filter).                          |
| `outbox_pending_count` | `0` if the pre-export flush succeeded; `N > 0` if the user is offline or the server rejected some mutations. |
| `outbox_pending_hash`  | SHA-256 over the sorted list of pending `mutation_id`s; `null` when `outbox_pending_count == 0`. |
| `photos_in_export`     | Hard-coded `false`. The assertion lives here so auditors don't have to scan for image files.     |
| `max_row_version_seen` | Highest `row_version` the export reflects; useful for staged re-imports later.                   |

## `README_export.txt`

Plain-text, ASCII, CRLF line endings so Windows spreadsheet users can double-click without mojibake. Contents (template):

```
Cestovni export — created {exported_at_utc}

This archive contains a full copy of the structured data you have
recorded in Cestovni for the account you exported from.

UNIT CONVENTIONS
  Distance canonical: meters (odometer_m)
  Distance display:   {unit_preferences.distance} (odometer_{km|mi})
  Volume canonical:   microliters (volume_uL)
  Volume display:     {unit_preferences.volume} (volume_{L|gal})
  Money canonical:    integer cents (total_price_cents)
  Money display:      {unit_preferences.currency} (total_price_major)

DISPLAY ROUNDING
  Volume:      2 decimals
  Distance:    0 decimals
  L/100km:     1 decimal (not exported as a column; derived in-app)
  Prices:      2 decimals

RECEIPT PHOTOS
  Photos are stored only on your device with a 30-day time-to-live.
  They are NOT included in this export. This is by design.

TIMESTAMPS
  All *_utc columns are ISO-8601 UTC.
  All *_local columns use your preferred timezone ({timezone}).

RE-IMPORT
  The CANONICAL columns (odometer_m, volume_uL, total_price_cents)
  are the source of truth. Derived columns (odometer_km, volume_L,
  total_price_major) are provided for convenience only and may lose
  precision after multiple open/save cycles in a spreadsheet.

OUTBOX STATUS
  outbox_pending_count = {N}
  If > 0, some mutations had not yet been saved to the server at
  the time of export. The data in the CSVs still reflects your
  local state at export time.
```

## CSV schema per entity

Every CSV uses the two-column pattern from [`si-units.md`](si-units.md) (canonical + derived). Common columns first, domain columns next, audit columns last.

> **Headers below were written 2026-04-17 and predate schema v2/v3.** `maintenance_events` gained `category` + `shop` (CES-53) and `settings` gained `default_vehicle_id` (CES-57); `maintenance_rules.notes` was never listed. See [§ v1 amendments](#v1-amendments-2026-08-16) for the authoritative header list.

### `vehicles.csv`

```csv
id,user_key_hash,name,make,model,year,vin,fuel_type,tank_capacity_uL,tank_capacity_L,archived_at_utc,row_version,updated_at_utc
```

### `fill_ups.csv`

```csv
id,user_key_hash,vehicle_id,filled_at_utc,filled_at_local,odometer_m,odometer_km,odometer_mi,volume_uL,volume_L,volume_gal,total_price_cents,total_price_major,currency_code,is_full,missed_before,odometer_reset,notes,row_version,updated_at_utc
```

### `maintenance_rules.csv`

```csv
id,user_key_hash,vehicle_id,name,cadence_km,cadence_days,enabled,row_version,updated_at_utc
```

### `maintenance_events.csv`

```csv
id,user_key_hash,vehicle_id,rule_id,performed_at_utc,performed_at_local,odometer_m,odometer_km,odometer_mi,cost_cents,cost_major,currency_code,notes,row_version,updated_at_utc
```

### `settings.csv`

One row per user.

```csv
user_key_hash,preferred_distance_unit,preferred_volume_unit,currency_code,timezone,row_version,updated_at_utc
```

### CSV rules

- **Encoding:** UTF-8 **with BOM** (Excel-friendly; non-Excel tools handle BOM fine).
- **Delimiter:** comma.
- **Line endings:** CRLF.
- **Quoting:** RFC 4180 — quote fields containing commas, quotes, or newlines; escape inner quotes by doubling.
- **Nulls:** empty field (not the string `NULL`).
- **Booleans:** `true` / `false`.
- **Soft-deleted rows are excluded.** `deleted_at IS NOT NULL` rows stay inside the app for sync but never leave in export.
- **Derived columns** follow display rounding from [`si-units.md`](si-units.md); canonical columns are integers, always.

## Assembly pipeline

```mermaid
flowchart TD
  user[User taps Export] --> precheck[Pre-flight checks]
  precheck --> flush["Outbox flush if online"]
  flush --> tx[BEGIN IMMEDIATE SQLite read txn]
  tx --> csvs[Stream rows into per-entity CSV writers]
  csvs --> zip[Stream CSVs + manifest + README into ZIP on disk]
  zip --> seal[Write to .tmp file]
  seal --> rename[Atomic rename to final filename]
  rename --> share[Platform share sheet]
  seal --> failCleanup["On any error: delete .tmp"]
```

1. **Pre-flight checks:** enough free disk (estimate: `rows × 400 bytes`, floor 5 MB); cleanup old photo TTLs (see [`photo-pipeline.md`](photo-pipeline.md)); if `outbox_pending_count > 0` and offline, surface a warning dialog offering to proceed anyway.
2. **Outbox flush (best-effort):** if online, POST the outbox so the export reflects a backed-up state. Success is **not** required to proceed; failure is reflected in `outbox_pending_count`.
3. **Snapshot semantics:** `BEGIN IMMEDIATE;` on the local SQLite. All CSVs + the manifest derive from the same read-consistent view. The transaction ends as soon as the last CSV is written; the ZIP finalization happens afterwards on disk.
4. **Streaming write:** row-by-row into a ZIP writer backed by a temporary file in the app sandbox. Memory footprint target: ≤ 10 MB for 10 000 fill-ups.
5. **Atomic rename:** the final filename appears only after the ZIP is successfully closed; partial exports are never visible to the user.
6. **Share:** iOS share sheet / Android intent. No in-app upload anywhere; the user controls destination.

## Error handling

| Failure                           | Behavior                                                                              |
| --------------------------------- | ------------------------------------------------------------------------------------- |
| Disk full mid-write               | Delete `.tmp`, show clear error with free-space estimate.                             |
| SQLite locked                     | Retry with backoff once; then fail the export and ask the user to try again.         |
| Outbox flush fails (network)      | Proceed with `outbox_pending_count > 0`; show informative README entry.              |
| CSV row serialization error       | Fail entire export; never emit a partial CSV into the ZIP. Log to crash SDK.         |
| ZIP finalization error            | Delete `.tmp`, fail the user-visible export.                                         |
| App backgrounded during export    | Export continues on a platform background task; on completion, surface a notification.|

Atomicity is a hard contract: either a valid ZIP exists at the final path, or no file exists. There is no state in between.

## Performance target

- **10 000 fill-ups** export on a mid-range Android (3 GB RAM) completes in ≤ 30 s with ≤ 10 MB peak memory.
- **1 000 fill-ups** export on any supported device completes in ≤ 5 s.

Both targets are validated by `tests/export/` fixtures.

## Non-goals (v1)

- **No incremental / diff exports.** Every export is the full structured state.
- **No re-import tool in-app (v1) — historical.** This non-goal was deferred, not permanent. In-app restore is [CES-70](https://linear.app/personal-interests-llc/issue/CES-70): Settings → **Import data**, specified in [`export-import.md`](export-import.md) (replace mode). Implementation + spec tests are on [PR #25](https://github.com/JMNofziger/cestovni/pull/25); not on `main` yet. Merge / live multi-device sync remains a v1.x item in [`sync-protocol.md`](sync-protocol.md#v1x-roadmap-pointer-only--tbd-in-this-pass).
- **No photos.** Period.
- **No signed / encrypted ZIP.** User-managed; they can encrypt after export if they want.

## Critical gaps / risks

- **Multiple currencies in `fill_ups`**: the CSV handles this per-row (`currency_code` column), but chart consumers that drop the column will mis-aggregate. Documented in `README_export.txt` rounding section; the UX for trends handles this already (see [`consumption-math.md`](consumption-math.md)).
- **Timezone drift**: `_local` columns reflect the export-time timezone; a user who changes timezone between exports will see different `_local` strings for the same `_utc`. Accept.
- **Row-count drift during export**: we hold a read transaction; writes that the user initiates during a long export are serialized after; this is the standard SQLite reader behavior and is acceptable.

## Test expectations

Tests landing in `tests/export/`:

1. **Golden ZIP** — export a fixed 50-row fixture; assert byte-stable canonical columns, valid `manifest.json`, correct filename format.
2. **Atomicity** — induce a simulated disk-full mid-write; assert no `.tmp` or final file remains.
3. **Photos excluded** — seed 10 photos; run export; assert zero image files in the ZIP and `photos_in_export == false`.
4. **Outbox flush recorded** — run export with 3 pending mutations; assert `outbox_pending_count == 3` and `outbox_pending_hash` is stable for a stable set.
5. **Large dataset** — 10 000 fill-ups; assert performance targets above.
6. **Re-import round-trip** — a separate canonical-columns-only round-trip test (parse CSVs back to a minimal model; assert stored rows match) validates the "canonical is source of truth" promise.

## v1 amendments (2026-08-16)

Decisions taken when CES-41 moved to next-coding, resolving drift between this spec (authored 2026-04-17) and the shipped client schema. These **override** the corresponding text above.

### A1 — Authoritative CSV headers

The **live Drift schema decides which columns exist**; the header order above decides where they sit. A column present in `client/lib/db/tables/` but missing from the 2026-04 header list appends to the domain block, immediately before `notes` (or before the audit columns when the table has no `notes`).

```csv
vehicles.csv
id,user_key_hash,name,make,model,year,vin,fuel_type,tank_capacity_uL,tank_capacity_L,archived_at_utc,row_version,updated_at_utc

fill_ups.csv
id,user_key_hash,vehicle_id,filled_at_utc,filled_at_local,odometer_m,odometer_km,odometer_mi,volume_uL,volume_L,volume_gal,total_price_cents,total_price_major,currency_code,is_full,missed_before,odometer_reset,notes,row_version,updated_at_utc

maintenance_rules.csv
id,user_key_hash,vehicle_id,name,cadence_km,cadence_days,enabled,notes,row_version,updated_at_utc

maintenance_events.csv
id,user_key_hash,vehicle_id,rule_id,performed_at_utc,performed_at_local,odometer_m,odometer_km,odometer_mi,cost_cents,cost_major,currency_code,category,shop,notes,row_version,updated_at_utc

settings.csv
user_key_hash,preferred_distance_unit,preferred_volume_unit,currency_code,timezone,default_vehicle_id,row_version,updated_at_utc
```

`user_id`, `deleted_at`, and `mutation_id` stay **out** of every CSV: `user_key_hash` stands in for the first, soft-deleted rows are filtered so the second is always null, and the third is sync bookkeeping with no portable meaning. `settings.id` also stays out — it equals the user id.

### A2 — Derived unit columns are unconditional

Every derived column ships on every export regardless of `settings` preferences: `odometer_km` **and** `odometer_mi`, `volume_L` **and** `volume_gal`. This overrides the implication in [`si-units.md`](si-units.md) §Rules 2 that preferences select the derived column, and the `{km|mi}` templating in the `README_export.txt` block above.

Reason: a fixed header makes the golden-ZIP test independent of user settings, and gives CES-70 import exactly one header contract to parse. `unit_preferences` in `manifest.json` still records what the user was looking at.

### A3 — `cadence_km` carries meters

`maintenance_rules.cadence_km` is **canonical meters** despite its name (see [`data-model.md`](data-model.md) § `maintenance_rules`). Export it verbatim under its schema name, and say so in `README_export.txt`. Do **not** rename or add a converted column in v1 — a rename is a migration, and CES-70 must round-trip against the same header. Renaming to `cadence_m` is a follow-up ticket.

### A4 — Performance targets are device-validated, not CI gates

The 10 000-fill-up / 30 s / 10 MB targets above are **not** a CI gate and are not required to close CES-41. Neither GitHub Actions nor the Cloud VM can measure them meaningfully (no device, no Android SDK).

Required instead: a test proving the assembler **streams** — that it never materializes all rows or all CSV bytes at once (e.g. a counting/chunk-observing sink over a ~1 000-row fixture). Device timing moves to the manual pass alongside [CES-68](https://linear.app/personal-interests-llc/issue/CES-68).

### A5 — No background export task

Export is **foreground-only** on Stage 1 Android. Drop the "app backgrounded → platform background task → completion notification" row from § Error handling. If the OS suspends or kills the app mid-export the existing atomicity contract already covers it: the `.tmp` never gets renamed, so no partial ZIP is ever visible, and the user retries.

Reason: a background service plus `POST_NOTIFICATIONS` (Android 13+) is real platform plumbing and a new runtime permission for a path that finishes in seconds at realistic data sizes — CES-40 deliberately avoided extra permissions. Show progress and keep the user on the screen. An export slow enough to need backgrounding is evidence for the perf ticket, not for background infrastructure.

## References

- [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) — export is a locked v1 decision.
- [`si-units.md`](si-units.md) — canonical + derived column contract.
- [`data-model.md`](data-model.md) — exact column lists.
- [`photo-pipeline.md`](photo-pipeline.md) — why photos are absent.
- [`sync-protocol.md`](sync-protocol.md) — outbox flush hook.
