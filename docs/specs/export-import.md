# Spec: Export ZIP import (device-to-device, zero-server)

**Status:** Draft — **executable except for one product lock.** Every engineering decision below is normative. **Merge vs replace is NOT decided** — see [§ Open questions for product](#open-questions-for-product). Do not start implementation until that lock lands.
**Linear:** [CES-70](https://linear.app/personal-interests-llc/issue/CES-70)
**Depends on:** [CES-41](https://linear.app/personal-interests-llc/issue/CES-41) export ([PR #21](https://github.com/JMNofziger/cestovni/pull/21), `client/lib/export/`)
**Blocks:** [CES-71](https://linear.app/personal-interests-llc/issue/CES-71) (`cadence_km` → `cadence_m` rename)
**Reads:** [`export-v1.md`](export-v1.md) § v1 amendments · [`data-model.md`](data-model.md) · [`si-units.md`](si-units.md) · [`photo-pipeline.md`](photo-pipeline.md) · [`sync-protocol.md`](sync-protocol.md) § v1.x roadmap

> **Contract source.** The authoritative CSV shape is the **shipped export code**, not the 2026-04 body of `export-v1.md`. Header strings live in `client/lib/export/headers.dart`; cell formatting lives in `client/lib/export/snapshot.dart` + `derived.dart`. Import MUST import those same header constants rather than re-declaring them, so export and import cannot drift.

---

## Purpose

Let a user move their structured history between two devices with **zero server**, using a ZIP the app produced itself. This is the cost-conscious / self-host-only continuity path named in [`sync-protocol.md` § v1.x roadmap](sync-protocol.md#v1x-roadmap-pointer-only--tbd-in-this-pass) and it closes the "no re-import tool" non-goal in [`export-v1.md`](export-v1.md#non-goals-v1) as *deferred, not permanent*.

**In scope:** read an export ZIP, validate it, write the five backed-up tables into local SQLite.
**Out of scope:** PWA-lite import, M3 server (CES-42–45), FX normalization (CES-51), the CES-71 rename, OCR, photo transfer.

## Current state vs expected outcome

| | Current | Expected after CES-70 |
|---|---|---|
| Export | Settings → **Export data** writes a STORE ZIP: `manifest.json`, `README_export.txt`, five CSVs | unchanged |
| Import | none — a ZIP is a dead end inside the app | Settings → **Import data** ingests a ZIP the app produced |
| Photos | never exported (`photos_in_export: false`) | never imported; a photo-shaped ZIP **fails closed** |
| `row_version` | client never writes it; CSV cells empty, manifest `null` | imported rows keep `row_version = NULL` (never synced) |
| Identity | `user_key_hash` = SHA-256(`settings.id`)[:8]; `settings.id` is **not** in the ZIP | local `settings.id` is never overwritten; source hash is advisory |
| Local-only tables | `drafts` / `photo_refs` / `outbox` excluded from export | import creates **no** rows in any of them |

---

## Input contract

### ZIP shape

Exactly these entries, produced by `exportZipEntryNames` in `client/lib/export/headers.dart`:

```
manifest.json
README_export.txt
vehicles.csv
fill_ups.csv
maintenance_rules.csv
maintenance_events.csv
settings.csv
```

- **Reader:** take entry sizes from the **central directory**, not local headers — CES-41 sets the data-descriptor flag (GP bit 3), so local-header CRC/size fields are zero. `client/test/export/zip_read.dart` already does this correctly; promote it to `client/lib/import/` rather than writing a second reader.
- **Compression:** our own exports are **STORE**. Also accept **DEFLATE** so a ZIP that passed through a cloud-storage tool still opens. Keep the parser pure by injecting an inflate callback (the service supplies the `dart:io` one).
- `README_export.txt` is **human-readable only** — never parsed for data.

### `manifest.json` gates

| Field | Import behaviour |
|---|---|
| `schema_version` | MUST equal `1` (`exportSchemaVersion`). Higher → reject with "exported by a newer version of Cestovni". |
| `photos_in_export` | MUST be `false`. Anything else → reject. |
| `row_counts` | MUST match the actual data-row count of every CSV. Mismatch → reject (the ZIP was edited). |
| `user_key_hash` | **Advisory only.** Never an authorization or matching key — see [§ Identity](#identity). |
| `max_row_version_seen` | Expected `null`. Non-null → reject (a server-versioned ZIP is out of scope until M3). |
| `outbox_pending_count` | Advisory. `> 0` surfaces a warning: the source device had unsynced mutations, so the ZIP is still its true local state but may predate a server write. |
| `exported_at_utc`, `app_version`, `app_platform`, `timezone`, `unit_preferences` | Displayed in the confirm dialog. Not applied as data. |

### CSV parsing rules

Mirror of `client/lib/export/csv.dart`, read direction:

- Strip a leading UTF-8 **BOM**; decode UTF-8.
- Accept **CRLF and LF** record separators (a tool may normalize line endings).
- **RFC 4180** quoting; doubled `""` is a literal quote.
- Empty field = `NULL`. Empty in a `NOT NULL` column → reject.
- Booleans: accept `true` / `false` **case-insensitively** (Excel upper-cases them). Reject `1`, `0`, `yes`, `no` — guessing there is how a silent data bug gets in.
- Integers: **strict**. Reject `1.0`, `1 234`, `1,234`, `+5`, leading zeros beyond a single `0`. Export writes bare digits with no grouping (`derived.dart`), so anything else means the file was edited.

### Header strictness

Each CSV's first record MUST be **byte-equal** (after BOM strip) to its constant in `client/lib/export/headers.dart`. On mismatch → reject and report expected vs found.

Rationale: amendment **A2** deliberately made headers independent of user preferences so import would have exactly one contract to parse. Tolerating column drift would throw that away.

- **Missing required CSV** → reject.
- **Unknown extra column** → reject. A column we do not understand may carry data we would silently drop.
- **Unknown extra ZIP entry** → **ignore with a warning** (cloud tools add `__MACOSX/`, users add notes), **except** anything matching the photo guard or a `photo_refs.csv`, which fails closed.

---

## Invariants

These hold regardless of how the merge-vs-replace lock resolves.

1. **Canonical only.** Import reads canonical INT64 columns and **ignores every derived column**: `odometer_km`, `odometer_mi`, `volume_L`, `volume_gal`, `total_price_major`, `cost_major`, `tank_capacity_L`, and all `*_local` timestamps. They must be *present* (header strictness) but their values are never read. `si-units.md` canonical columns are the only source of truth.
2. **`cadence_km` is meters, verbatim.** Read the `cadence_km` cell straight into the `cadence_km` column with **no conversion**. The audit in [§ Cadence units](#cadence-units-audit-result) confirms every existing write path already stores meters. Never accept a converted or renamed cadence column while `schema_version` is `1`.
3. **Photos never enter.** `photos_in_export == false` or fail closed. No `photos/` entry, no image bytes, no `photo_refs` row created. Reuse `client/lib/photos/photo_export_guard.dart` (`isPhotoSandboxPath`, `photosInExport`) — do not re-decide which paths are safe.
4. **No local-only rows created.** `drafts`, `photo_refs`, and `outbox` row counts are **unchanged** by an import. Export omitted them; import must not invent them.
5. **Imported rows are never-synced.** `row_version = NULL`, `user_id` left unset (server-assigned on first write per `data-model.md` § Protocol columns), `deleted_at = NULL`, `mutation_id` **freshly generated** locally. An imported row must not look "already backed up".
6. **`updated_at` is preserved** from the CSV. It is the row's real last-modified instant and is what any later reconciliation would compare.
7. **Local identity is never overwritten.** `settings.id` stays as-is. The ZIP does not contain it (excluded by A1), so this is structurally safe — do not reconstruct it from `user_key_hash`.
8. **Atomic.** The entire import runs in **one Drift transaction**. Any failure → full rollback, database byte-identical to before. Same hard contract as export's `.tmp`-never-renamed rule.
9. **Idempotent.** Importing the same ZIP twice produces the same database state as importing it once. No duplicate `id`s, ever.
10. **`id`s are preserved, never remapped.** See [§ `id` collisions](#id-collisions).

---

## Decisions

### Identity

Export carries no `user_id` (server-assigned, never client-sent) and no `settings.id`. `user_key_hash` is a **stand-in** — first 8 hex of SHA-256 over the source device's `settings.id` — because telemetry (CES-46) is not wired.

**Device B importing device A's ZIP will always see a different `user_key_hash` than its own.** That is the normal case, not an error.

- Import **never** rejects on hash mismatch. Rejecting would break the entire feature.
- The confirm dialog **shows both** hashes ("this archive: `a1b2c3d4` · this device: `e5f6a7b8`") so a user can tell their own export from a file they were handed.
- Imported rows inherit device B's identity. When M3 lands, `user_id` is assigned by the server on first write, so the rows become device B's — which is correct for a zero-server transfer.

### `id` collisions

UUIDs are v4, client-generated, and **stable across devices** (`data-model.md` § Conventions). The same logical row exported from A keeps its `id` when imported to B. That property is exactly what makes re-import idempotent.

**Locked: keep the ZIP's `id`. Never generate a new one for an imported row.** Remapping would fork history and make every subsequent import of the same ZIP duplicate everything.

What happens when an incoming `id` already exists locally as a live row is the merge-vs-replace lock. `reject` is wrong under either option — it would make a repeat import impossible.

### `row_version` and the outbox

CSV `row_version` cells are empty and `max_row_version_seen` is `null` because the client never assigns versions before M3.

**Locked: import does NOT enqueue outbox rows.** Write rows directly; leave `row_version = NULL`; create zero outbox entries.

Rationale:

1. There is no production server to drain to. Enqueuing would leave a permanent pile of pending mutations that corrupts `outbox_pending_count` in every later export.
2. `row_version IS NULL` is already the protocol's "never synced" state. Nothing extra is needed to represent it.
3. Only `fill_ups` enqueues at all today (`client/lib/db/repositories/fill_ups_repository.dart`); vehicles, settings, and maintenance have no enqueue path — that is CES-44's remaining scope, not this ticket's.

**Forward dependency (engineering seam, owned by CES-44 / CES-45):** when the outbox covers all five tables and a real server exists, imported rows need an explicit decision about whether they get pushed on first sync or wait to be touched. Record it on CES-44 when that work starts; do not pre-build it here.

### `settings` handling

`settings.csv` has exactly one data row (reject otherwise) and no `id` column.

- **Adopt** `preferred_distance_unit`, `preferred_volume_unit`, `currency_code`, `timezone` from the ZIP. These are display-only preferences — canonical storage is unaffected, and the point of an import is to make device B look like device A. Trivially reversible in Settings.
- **`default_vehicle_id`:** adopt only if that vehicle id exists after the import completes. Otherwise leave it `NULL` (CES-57 already validates the default against live vehicles).
- **`settings.id`, `user_id`, `row_version`:** untouched.

### Referential integrity

Apply in FK-parent order inside the single transaction:

```
vehicles → maintenance_rules → fill_ups → maintenance_events → settings
```

`settings` is last because `default_vehicle_id` references a vehicle.

A `fill_ups.vehicle_id`, `maintenance_events.vehicle_id`, or `maintenance_events.rule_id` that is present in neither the ZIP nor the live local database → **reject the whole import**. An orphaned row is invisible in History (which filters by vehicle) and would be silent data loss dressed up as success.

### Value validation

Re-validate every canonical value against the same constraints the DB enforces (`data-model.md` § Constraints summary) **before** any write, because a ZIP is a user-editable file:

- non-negative: `odometer_m`, `volume_uL`, `total_price_cents`, `cost_cents`, `tank_capacity_uL`
- `cadence_km > 0` / `cadence_days > 0`, and **at least one non-null** per rule
- enums: `fuel_type`, `category`, `preferred_distance_unit`, `preferred_volume_unit`
- `currency_code` matches `^[A-Z]{3}$`
- length bounds: `name` 1–80, `notes` ≤ 500, `shop` 1–120, `vin` ≤ 32, `timezone` 1–64
- `year` between 1900 and 2100
- timestamps parse as ISO-8601 UTC

Report the **file, line, and column** on the first violation and reject. Do not partially import.

**Nothing to recompute.** Consumption math is derived at read time (`client/lib/consumption/`) and no aggregates are cached, so importing fill-ups needs no recalculation pass. Odometer-regression validation is an *entry-time* rule (`validateInsert`) and is **not** re-run on import — the ZIP is an already-accepted history, and re-running it would reject legitimate archives containing a reset.

### UX

Settings → **Backup** section, directly under **Export data**, as a `LedgerTile` labelled **Import data**. Reuse existing tokens; no new visual language.

Flow: file picker → parse + validate (no writes) → **confirm dialog** showing row counts per table, source `user_key_hash` vs local, `exported_at_utc`, the source's `outbox_pending_count` warning if non-zero, and the selected mode → apply in one transaction → summary of rows written.

**Foreground-only**, matching export amendment A5: no background service, no completion notification, no new runtime permission. An import of realistic size finishes in seconds; if the OS kills the app mid-import the transaction rolls back.

**Safety:** offer **Export data first** inline from the confirm dialog. Under a destructive mode this is not optional politeness — it is the only recovery path.

---

## Cadence units audit result

Run 2026-08-16 against `main` (`dc6f2f9`), read-only, as the blocking precondition on CES-71.

**Result: CLEAN. Every write path stores canonical meters. CES-71 stays a cosmetic rename.**

| Path | Finding |
|---|---|
| `MaintenanceEventsRepository.upsertReminderRule` | Only writer of `cadence_km`. Writes `MaintenanceRuleDraft.cadenceKmMeters` verbatim — no conversion, correctly. |
| `maintenance_page.dart` `_save` | Only caller. Converts through `distanceToMeters(distVal, _distanceUnit)` before building the draft. |
| `maintenance_page.dart` `_loadRule` | Reads back through `metersToDisplayWhole(rule.cadenceKm!, _distanceUnit)` — round-trips. |
| `constraints_test.dart`, `roundtrip_test.dart` | Raw SQL inserts write `NULL` cadence to exercise the table CHECK. No unit exposure. |
| `maintenance_events_repository_test.dart` | `10_000_000` / `15_000_000` = 10 000 / 15 000 km. Plausible service intervals; intent matches meters. |
| PWA-lite (`client/web-lite/`), `tests/client-db/fixtures/` | No cadence references at all. |
| Export `ruleCsvRow` | Emits `r.cadenceKm` verbatim per A3. |

Runtime confirmation of the entry → canonical → display chain:

```
km entry 10   -> 10000 m stored        10000 m    -> 10 km shown
km entry 5000 -> 5000000 m stored      16093 m    -> 10 mi shown
mi entry 10   -> 16093 m stored        10000000 m -> 10000 km shown
mi entry 5000 -> 8046720 m stored
```

A user typing `10` with `km` prefs persists `10000`, and `mi` prefs convert. The failure mode CES-71 asked about does not exist.

**One real gap, not a bug:** no test covers the **form-level** cadence conversion. `maintenance_page_test.dart` fills only the months field (asserts `cadenceDays == 180`) and leaves remind-distance empty; the repository test passes meters directly, bypassing `distanceToMeters`. So `maintenance_page.dart` `_save` — the single line where a unit mistake could ever enter — is uncovered. CES-71 renames exactly that path, so it should add the assertion as part of its own regression net.

**CES-71 obligation carried forward:** after the rename, import must accept `cadence_km` for `schema_version: 1` ZIPs **and** `cadence_m` for `schema_version: 2`, or the manifest bump must document the break. A user's existing backup file must not become unreadable.

---

## Error handling

Every code below aborts before or inside the transaction and leaves the database **unchanged**.

| Code | Condition |
|---|---|
| `E_NOT_A_ZIP` | Not a readable ZIP; EOCD or central directory unparseable. |
| `E_MISSING_MANIFEST` | `manifest.json` absent. |
| `E_MANIFEST_INVALID` | Not JSON, or a required key is missing. |
| `E_SCHEMA_VERSION_UNSUPPORTED` | `schema_version != 1`. Message names the app-version skew. |
| `E_PHOTOS_PRESENT` | `photos_in_export != false`, any `photos/`-shaped entry, image bytes, or a `photo_refs.csv`. **Fail closed.** |
| `E_ROW_VERSION_PRESENT` | `max_row_version_seen` non-null, or any non-empty `row_version` cell. |
| `E_MISSING_CSV` | One of the five required CSVs is absent. |
| `E_HEADER_MISMATCH` | Header not byte-equal to the `headers.dart` constant. Reports expected vs found. |
| `E_ROW_MALFORMED` | Wrong field count, unterminated quote. Reports file + line. |
| `E_VALUE_INVALID` | Non-integer in a canonical column, negative value, enum miss, bad currency, length bound, bad boolean, empty in `NOT NULL`. Reports file + line + column. |
| `E_CADENCE_MISSING` | Rule row with both `cadence_km` and `cadence_days` empty. |
| `E_FK_ORPHAN` | `vehicle_id` / `rule_id` resolves to nothing in the ZIP or locally. |
| `E_SETTINGS_ROW_COUNT` | `settings.csv` does not have exactly one data row. |
| `E_COUNT_MISMATCH` | Data-row count disagrees with `manifest.row_counts`. |
| `E_TXN_FAILED` | Any write, disk, or constraint failure. Transaction rolls back. |

**Warnings (non-fatal, surfaced in the confirm dialog or summary):** `W_UNKNOWN_ENTRY` (extra non-photo ZIP entry ignored) · `W_DIFFERENT_SOURCE_KEY` (`user_key_hash` differs from local — expected for device-to-device) · `W_SOURCE_HAD_PENDING_OUTBOX` (`outbox_pending_count > 0` in the source manifest).

---

## Suggested layout

Mirror the `client/lib/export/` split so the pure parser stays testable without Drift:

```
client/lib/import/
  zip_read.dart      # central-directory reader, promoted from client/test/export/zip_read.dart
  csv_parse.dart     # BOM strip, RFC 4180, strict int/bool coercion
  validate.dart      # manifest gates, header check, per-column constraints → typed errors
  plan.dart          # parsed + validated rows, counts, warnings — no DB
  apply.dart         # Drift writes in FK order, single transaction
  import_service.dart# file picker, inflate injection, orchestration
```

`headers.dart` is **imported from `client/lib/export/`**, never copied. Add a test asserting import's expected header set *is* the export constant set, so the two can never drift.

---

## Test expectations

Land in `client/test/import/` with a pointer row added to `tests/export/README.md` (or a sibling `tests/import/README.md`), matching how CES-41 mapped spec expectations to files.

1. **Golden round-trip** — export the CES-41 fixture, import into an empty DB, assert row-for-row equality on every canonical column. Strongest single proof; reuses the existing golden fixture.
2. **Idempotency** — import the same ZIP twice; row counts unchanged, no duplicate `id`s.
3. **Header strictness** — mutate one header cell → `E_HEADER_MISMATCH`, zero writes.
4. **Photo fail-closed** — inject `photos/x.jpg`; and separately set `photos_in_export: true` → `E_PHOTOS_PRESENT` both times, zero writes.
5. **Derived columns ignored** — corrupt `odometer_km` to a wrong value; assert the stored `odometer_m` still comes from the canonical cell.
6. **Cadence meters** — a rule with `cadence_km = 10000` stores `10000` (not `10`, not `10000000`).
7. **Value validation** — negative `volume_uL`, `1.0` in an INT column, bad `currency_code`, unknown `fuel_type`, unknown `category`: each rejects with the DB untouched.
8. **Atomicity** — induce a failure while writing the last table; assert zero rows written anywhere.
9. **No local-only rows** — `drafts`, `photo_refs`, `outbox` counts identical before and after.
10. **Never-synced state** — imported rows have `row_version IS NULL`; outbox count unchanged.
11. **FK orphan** — `fill_ups.vehicle_id` pointing nowhere → `E_FK_ORPHAN`.
12. **Settings** — prefs adopted; `settings.id` unchanged; `default_vehicle_id` dropped when the vehicle is absent.
13. **Module purity** — `csv_parse` / `validate` / `plan` import no Flutter, Drift, or `dart:io`, mirroring `client/test/export/module_purity_test.dart`.
14. **Streaming** — parse a ~1 000-row CSV without materializing every row at once, matching amendment **A4**'s posture (device timing is not a CI gate).
15. **Mode behaviour** — named but **not writable** until the merge-vs-replace lock lands.

Not a CI gate, per A4: device timing on a large archive. Fold into the CES-68 manual pass.

---

## Open questions for product

### 1. Merge vs replace — BLOCKING

CES-70 says "merge vs replace on import is a product decision — lock before coding." It is still open, so this spec does not choose. Both options are complete enough to build from.

**Option A — Replace (destructive restore).** Clear the five backed-up tables, insert the ZIP's rows.

- One obvious mental model: "this device now matches this archive."
- No conflict rules, no LWW, fully deterministic, testable to a high bar immediately.
- Local-only data (`drafts`, `photo_refs`, `outbox`) is untouched, but photos on device B become **orphaned** — their `photo_refs` rows point at fill-up ids that may no longer exist. The TTL sweep already collects orphans, so they expire rather than leak.
- Cost: anything logged on device B and not in the archive is **gone**.

**Option B — Merge (upsert by `id`).** Insert unknown `id`s; for known `id`s either skip or overwrite by `updated_at` last-write-wins.

- Non-destructive; supports two devices both in active use.
- Needs a conflict matrix we do not have, and LWW silently loses whichever edit is older.
- **Cannot express deletions.** Export omits soft-deleted rows, so a row deleted on A still exists on B and merge will never remove it. Users accumulate zombie rows with no reconciliation path.

**Recommendation: Option A (replace) for the CES-70 pass, behind a typed confirmation, with merge deferred to v1.x.**

- The use case named on CES-70 is moving to a new phone — that is a restore, not two-way sync.
- A merge that can never delete is dishonest; an honest replace is the better product.
- LWW merge *is* the v1.x field-level merge problem ADR 002 deliberately deferred. Half-building it here pre-empts that decision with a worse implementation.
- Safety is a UX problem (typed confirm + inline "export first", which we can offer now that CES-41 shipped), not an architecture problem.

**What breaks if we guess wrong:** Build replace when product wanted merge → users logging on both devices lose the device-B tail, recoverable only if they exported first. Build merge when product wanted replace → deleted-on-A rows resurrect as zombies, there is no clean "make B match A", and the v1.x merge-rules decision is spent on an unspecified implementation. Both wrong guesses are expensive, which is why this stays a lock rather than a default.

### 2. Cross-account imports — confirm the position

This spec treats a differing `user_key_hash` as a warning, not an error, because that is the normal device-to-device case and the hash is only a stand-in until CES-46. That means nothing stops a user importing a ZIP a *friend* handed them, merging someone else's history into their own.

Proposed position: **acceptable for v1** — it is the user's own device and their own file, there is no server, and no account boundary exists to violate. The confirm dialog showing both hashes is sufficient disclosure. **Confirm or override.**

---

## References

- [`export-v1.md`](export-v1.md) — export contract; § v1 amendments A1–A5 are the authoritative CSV shape.
- [`data-model.md`](data-model.md) — column types, constraints, protocol columns, client-only tables.
- [`si-units.md`](si-units.md) — canonical INT64 storage; derived columns are display-only.
- [`photo-pipeline.md`](photo-pipeline.md) — why photos are absent from both directions.
- [`sync-protocol.md`](sync-protocol.md) — outbox / `row_version` semantics; § v1.x roadmap names this ticket.
- [ADR 002](adr/002-backup-sync-layer.md) — deferred field-level merge rules.
