# Spec: Export ZIP import (device-to-device, zero-server)

**Status:** **Complete (v1) — ready for implementation.** All product locks resolved 2026-08-16 (see [§ Product decisions](#product-decisions-locked-2026-08-16)). Mode is **replace**.
**Linear:** [CES-70](https://linear.app/personal-interests-llc/issue/CES-70)
**Depends on:** [CES-41](https://linear.app/personal-interests-llc/issue/CES-41) export ([PR #21](https://github.com/JMNofziger/cestovni/pull/21), `client/lib/export/`)
**Blocks:** [CES-71](https://linear.app/personal-interests-llc/issue/CES-71) (`cadence_km` → `cadence_m` rename)
**Reads:** [`export-v1.md`](export-v1.md) § v1 amendments · [`data-model.md`](data-model.md) · [`si-units.md`](si-units.md) · [`photo-pipeline.md`](photo-pipeline.md) · [`sync-protocol.md`](sync-protocol.md) § v1.x roadmap

> **Contract source.** The authoritative CSV shape is the **shipped export code**, not the 2026-04 body of `export-v1.md`. Header strings live in `client/lib/export/headers.dart`; cell formatting lives in `client/lib/export/snapshot.dart` + `derived.dart`. Import MUST import those same header constants rather than re-declaring them, so export and import cannot drift.

---

## Purpose

Let a user move their structured history between two devices with **zero server**, using a ZIP the app produced itself. This is the cost-conscious / self-host-only continuity path named in [`sync-protocol.md` § v1.x roadmap](sync-protocol.md#v1x-roadmap-pointer-only--tbd-in-this-pass) and it closes the "no re-import tool" non-goal in [`export-v1.md`](export-v1.md#non-goals-v1) as *deferred, not permanent*.

**In scope:** read an export ZIP, validate it, replace the five backed-up tables in local SQLite.
**Out of scope:** PWA-lite import, M3 server (CES-42–45), FX normalization (CES-51), the CES-71 rename, OCR, photo transfer.

## Current state vs expected outcome

| | Current | Expected after CES-70 |
|---|---|---|
| Export | Settings → **Export data** writes a STORE ZIP: `manifest.json`, `README_export.txt`, five CSVs | unchanged |
| Import | none — a ZIP is a dead end inside the app | Settings → **Import data** replaces local history from a ZIP the app produced |
| Mode | undecided | **Replace** — destructive restore, typed confirmation when there is data to lose |
| Photos | never exported (`photos_in_export: false`) | never imported; a photo-shaped ZIP **fails closed** |
| `row_version` | client never writes it; CSV cells empty, manifest `null` | imported rows keep `row_version = NULL` (never synced) |
| Identity | `user_key_hash` = SHA-256(`settings.id`)[:8]; `settings.id` is **not** in the ZIP | local `settings.id` never overwritten; source hash advisory only |
| Local-only tables | `drafts` / `photo_refs` / `outbox` excluded from export | `outbox` cleared; `drafts`/`photo_refs` preserved except for destroyed vehicles |

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

1. **Canonical only.** Import reads canonical INT64 columns and **ignores every derived column**: `odometer_km`, `odometer_mi`, `volume_L`, `volume_gal`, `total_price_major`, `cost_major`, `tank_capacity_L`, and all `*_local` timestamps. They must be *present* (header strictness) but their values are never read. `si-units.md` canonical columns are the only source of truth.
2. **`cadence_km` is meters, verbatim.** Read the `cadence_km` cell straight into the `cadence_km` column with **no conversion**. The audit in [§ Cadence units](#cadence-units-audit-result) confirms every existing write path already stores meters. Never accept a converted or renamed cadence column while `schema_version` is `1`.
3. **Photos never enter.** `photos_in_export == false` or fail closed. No `photos/` entry, no image bytes, no `photo_refs` row created **from the ZIP**. Reuse `client/lib/photos/photo_export_guard.dart` (`isPhotoSandboxPath`, `photosInExport`) — do not re-decide which paths are safe.
4. **No local-only rows are created.** Import never inserts into `drafts`, `photo_refs`, or `outbox`. Their *removal* under replace is governed by [§ Replace semantics](#replace-semantics).
5. **Imported rows are never-synced.** `row_version = NULL`, `user_id` left unset (server-assigned on first write per `data-model.md` § Protocol columns), `deleted_at = NULL`, `mutation_id` **freshly generated** locally. An imported row must not look "already backed up".
6. **`updated_at` is preserved** from the CSV. It is the row's real last-modified instant and is what any later reconciliation would compare.
7. **Local identity is never overwritten.** `settings.id` stays as-is. The ZIP does not contain it (excluded by A1), so this is structurally safe — do not reconstruct it from `user_key_hash`, and never `DELETE` the `settings` row.
8. **Atomic.** All database work runs in **one Drift transaction**. Any failure → full rollback, database byte-identical to before. Same hard contract as export's `.tmp`-never-renamed rule. The only post-commit step is photo **file** deletion, which is crash-safe by design (see [§ Replace semantics](#replace-semantics)).
9. **Idempotent.** Importing the same ZIP twice produces the same database state as importing it once.
10. **`id`s are preserved, never remapped.** UUIDs are v4 and stable across devices (`data-model.md` § Conventions), so a row keeps its identity across the transfer. Remapping would fork history.

---

## Replace semantics

**Mode: replace.** Locked 2026-08-16 — rationale in [§ Product decisions](#product-decisions-locked-2026-08-16).

The import makes local history match the archive exactly. Per-table disposition:

| Table | Disposition | Why |
|---|---|---|
| `vehicles`, `fill_ups`, `maintenance_rules`, `maintenance_events` | **Hard `DELETE`, then insert from the ZIP** | Replace means match the archive. Soft-delete would leave rows whose `id` collides with incoming rows on the primary key. |
| `settings` | **`UPDATE` in place — never deleted** | Deleting it would destroy `settings.id`, violating invariant 7. It is a single bootstrapped row, so there is nothing to clear. |
| `outbox` | **Cleared** | Every row describes a mutation on one of the four replaced tables (enforced by the `table` CHECK in `client/lib/db/tables/outbox.dart`). Keeping them would later push rows the user explicitly replaced. Disclosed in the confirm dialog. |
| `drafts` | **Preserved when the draft's `vehicle_id` survives the import; discarded when its vehicle is destroyed** | A draft is unsaved typing. Drafts are looked up by vehicle (`DraftsRepository.openDraftForVehicle`), so a draft whose vehicle is gone is unreachable by construction — and would silently resurface if that vehicle id ever returned in a later import. Because UUIDs are stable across devices, importing your *own* archive normally preserves every draft. |
| `photo_refs` + JPEG files | **Follow `drafts`** | `photo_refs.draft_id` is a foreign key to `drafts` (not `fill_ups`), and `ttl_expires_at` is an absolute stamp on the row, so replacing fill-ups orphans nothing and changes no TTL. Only the photos of a *discarded* draft are purged. |

### Ordering

Inside the single transaction:

1. Parse + validate everything. **No writes until validation passes.**
2. `DELETE` children before parents: `maintenance_events` → `fill_ups` → `maintenance_rules` → `vehicles`.
3. Clear `outbox`.
4. Insert in FK-parent order: `vehicles` → `maintenance_rules` → `fill_ups` → `maintenance_events`.
5. `UPDATE settings` in place.
6. Reconcile `drafts` against the now-live `vehicles`: for each draft whose `vehicle_id` is absent, delete its `photo_refs` rows and then the draft row (collecting the photo ids), honouring the FK order — `photo_refs.draft_id` has no `ON DELETE CASCADE`.

After commit, delete the collected JPEG **files** from the sandbox. This ordering is deliberately crash-safe: an interruption between commit and file deletion leaves files with no row, which the existing CES-40 sweep already collects as `orphanFilesDeleted` (`PhotoService.sweep`). Never delete files before the transaction commits — a rollback would leave rows pointing at missing files.

### Confirmation

- **Local history is non-empty** (any row across the four replaced tables): require the user to type `REPLACE` exactly, and offer **Export current data first** inline. This is the only recovery path — there is **no undo**.
- **Local history is empty** (fresh install / new phone — the primary use case): plain confirm, no typed keyword, no export offer. There is nothing to lose and friction there buys no safety.

The typed keyword is English and un-localized because the client has no i18n in v1. If localization lands, the keyword must be localized or replaced with a non-text affordance — do not leave an English-only destructive gate in a translated UI.

### Referential integrity under replace

Because the four history tables are cleared first, a `fill_ups.vehicle_id`, `maintenance_events.vehicle_id`, or `maintenance_events.rule_id` must resolve **within the ZIP**. There is no "or already live locally" fallback under replace. Unresolvable → reject the whole import; an orphaned row is invisible in History (which filters by vehicle) and would be silent data loss dressed up as success.

`settings.default_vehicle_id` is adopted only if that vehicle is present in the ZIP; otherwise it is set to `NULL` (CES-57 already validates the default against live vehicles).

---

## Decisions

### Identity

Export carries no `user_id` (server-assigned, never client-sent) and no `settings.id`. `user_key_hash` is a **stand-in** — first 8 hex of SHA-256 over the source device's `settings.id` — because telemetry (CES-46) is not wired.

**Device B importing device A's ZIP will always see a different `user_key_hash` than its own.** That is the normal case, not an error.

- Import **never** rejects on hash mismatch. Rejecting would break the entire feature.
- The confirm dialog **shows both** hashes ("this archive: `a1b2c3d4` · this device: `e5f6a7b8`") so a user can tell their own export from a file they were handed.
- Imported rows inherit device B's identity. When M3 lands, `user_id` is assigned by the server on first write, so the rows become device B's — correct for a zero-server transfer.

See [§ Cross-account imports](#2-cross-account-imports--warning-only-revisit-gated) for the accepted risk and its revisit gate.

### `row_version` and the outbox

CSV `row_version` cells are empty and `max_row_version_seen` is `null` because the client never assigns versions before M3.

**Locked: import does NOT enqueue outbox rows.** Write rows directly; leave `row_version = NULL`; create zero outbox entries. Replace additionally *clears* the existing queue, per [§ Replace semantics](#replace-semantics).

Rationale:

1. There is no production server to drain to. Enqueuing would leave a permanent pile of pending mutations that corrupts `outbox_pending_count` in every later export.
2. `row_version IS NULL` is already the protocol's "never synced" state. Nothing extra is needed to represent it.
3. Only `fill_ups` enqueues at all today (`client/lib/db/repositories/fill_ups_repository.dart`); vehicles, settings, and maintenance have no enqueue path — that is CES-44's remaining scope, not this ticket's.

**Forward dependency (engineering seam, owned by CES-44 / CES-45):** when the outbox covers all five tables and a real server exists, imported rows need an explicit decision about whether they get pushed on first sync or wait to be touched, and clearing the queue on replace stops being a no-cost operation. Record it on CES-44 when that work starts; do not pre-build it here.

### `settings` handling

`settings.csv` has exactly one data row (reject otherwise) and no `id` column.

- **Adopt** `preferred_distance_unit`, `preferred_volume_unit`, `currency_code`, `timezone` from the ZIP. These are display-only preferences — canonical storage is unaffected, and the point of an import is to make device B look like device A. Trivially reversible in Settings.
- **`default_vehicle_id`:** adopt only if that vehicle is present in the ZIP; else `NULL`.
- **`settings.id`, `user_id`, `row_version`:** untouched. `UPDATE`, never `DELETE` + insert.

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

Flow: file picker → parse + validate (no writes) → **confirm dialog** → apply → summary.

The confirm dialog shows: per-table row counts coming in, what will be removed (row counts per table, queued-change count, affected drafts), source `user_key_hash` vs local, `exported_at_utc`, the source's `outbox_pending_count` warning when non-zero, and the typed-keyword field when local history is non-empty.

The summary reports: rows written per table, rows replaced, queued changes discarded, drafts discarded, photos purged.

**Foreground-only**, matching export amendment A5: no background service, no completion notification, no new runtime permission. An import of realistic size finishes in seconds; if the OS kills the app mid-import the transaction rolls back.

User-facing wording is specified in [§ User-facing explanation](#user-facing-explanation).

---

## Product decisions (locked 2026-08-16)

### 1. Replace, not merge

**Decision: replace.** The import makes local history match the archive. Merge is deferred to v1.x and is not built, not stubbed, and not selectable.

#### Technical rationale

1. **Merge cannot express deletions, so it is not a correctness-preserving operation.** Export deliberately omits soft-deleted rows (`export-v1.md` § CSV rules — `deleted_at IS NOT NULL` rows never leave the device). A merge therefore sees no tombstones and has no mechanism to remove anything. A vehicle or fill-up the user deleted on device A would survive on device B forever, and every subsequent import would re-affirm it. Users accumulate zombie rows with no reconciliation path and no way to tell which rows are real. Replace has no such class of bug: the archive is the complete live state by construction.

2. **Merge requires the conflict rules ADR 002 explicitly deferred.** Upsert-by-`id` needs a winner when both sides have the same `id` with different content. The only tiebreak available pre-M3 is last-write-wins on `updated_at`, because `row_version` is `NULL` on every client row until a server assigns it. LWW at row granularity silently discards the losing side's edits. [ADR 002](adr/002-backup-sync-layer.md) deferred field-level merge rules to v1.x precisely so this would be specified before it was built; implementing a row-level LWW merge here would spend that decision on an unspecified design and then constrain the real one for backwards compatibility.

3. **Replace matches the actual use case.** CES-70 exists so a user can move to a new phone or recover on a reinstall — a restore, not two-way sync. In that scenario the destination is empty, which makes replace and merge behaviourally identical *and* means the destructive path never fires for the primary user journey.

4. **Replace is verifiable now; merge is not.** Replace has one deterministic post-state, so the golden round-trip test (export fixture → import → row-for-row canonical equality) is a complete proof of correctness. Merge would need a conflict matrix across five tables and three row states that no spec defines, and its tests would encode guesses rather than requirements.

5. **The risk replace carries is a UX problem, not an architecture problem.** Data loss is bounded by a typed confirmation, an inline export-first offer, and skipping both when there is nothing to lose. That is a well-understood pattern. The risk merge carries — silent, unbounded, undetectable divergence between two devices — cannot be mitigated by UI.

**Consequences accepted:** anything logged on the destination and absent from the archive is destroyed, with no undo. Queued unsynced changes are discarded. Drafts for destroyed vehicles are discarded along with their receipt photos. All are disclosed pre-flight and enumerated in the summary.

**Revisit gate:** merge becomes worth specifying when v1.x field-level merge rules land in `sync-protocol.md` **and** export carries tombstones so deletions are representable. Both are prerequisites, not nice-to-haves.

#### User-facing explanation

Plain-language copy, safe to reuse in `docs/product/install-*.md`, an in-app help sheet, or the confirm dialog. No jargon, and honest about the destructive part.

> **Importing a backup replaces what is on this device**
>
> Cestovni can move your history to another phone using a backup file you export yourself. No account and no server are involved — the file goes wherever you send it, and nothing is uploaded.
>
> Importing is a **restore**, not a merge. When you import a backup, Cestovni makes this device match that file exactly: your vehicles, fill-ups and maintenance records are replaced by the ones in the backup. Anything you logged on this device that is not in the backup will be gone, and there is no undo.
>
> That is why we do not merge two devices together. A backup file only lists the records that exist — it has no way to say "this vehicle was deleted". If we merged, anything you had ever deleted on the other phone would quietly come back, and you would have no way to tell real records from resurrected ones. Replacing is the honest version: you always know exactly what you end up with.
>
> **So the safe order is:**
>
> 1. On the phone that has the history you want to keep, tap **Export data** and save the file somewhere you can reach — a cloud drive, a chat to yourself, a cable transfer.
> 2. On the other phone, tap **Import data** and pick that file.
> 3. If that phone already has records of its own, export them first. We offer this on the confirmation screen, and it is the only way to get them back afterwards.
>
> On a brand-new phone there is nothing to lose, so we skip the warnings and just import.
>
> **A few details worth knowing:**
>
> - **Receipt photos are never included.** They stay on the phone that took them and expire on their own. This is deliberate — photos are never uploaded or exported.
> - **Your unit and currency preferences travel with the backup**, so the new phone displays things the way the old one did. You can change them in Settings at any time.
> - **If you were waiting on a backup to the cloud**, those pending changes are discarded when you import, because the records they describe are being replaced.
> - **A half-finished fill-up you had not saved yet** is kept if its vehicle is still there after the import, and discarded if that vehicle is not.

### 2. Cross-account imports — warning only, revisit-gated

**Decision: keep it a warning, not a rejection. Documented for revisit at greater project maturity.**

A differing `user_key_hash` is the *normal* device-to-device case, so it cannot be an error. The consequence is that nothing prevents a user importing an archive someone else handed them, merging another person's history into their own view.

Accepted for v1 because:

- There is no account, no server, and no authentication in the product yet, so there is no boundary to violate. The only actor is the device owner acting on a file they chose.
- `user_key_hash` is a **stand-in** derived from a local UUID (CES-46 telemetry is not wired). Treating it as an identity claim would give a placeholder security meaning it cannot carry.
- Replace makes the outcome legible rather than covert: the destination becomes the archive, so a user cannot end up with a silent blend of two people's records.
- Disclosure is adequate — the confirm dialog shows both hashes side by side.

**Revisit when either becomes true:**

1. **CES-46 lands a real telemetry user key**, so `user_key_hash` stops being a local placeholder and starts denoting a person.
2. **M3 (CES-42 / CES-43) introduces server accounts and auth**, creating a genuine account boundary — at which point importing across accounts needs a considered position, and `user_id` reassignment on first sync needs to be explicit rather than incidental.

Until then this is a recorded, deliberate acceptance rather than an oversight. Re-open this section when either trigger fires; do not treat the v1 position as settled beyond that point.

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
| `E_FK_ORPHAN` | `vehicle_id` / `rule_id` does not resolve **within the ZIP**. |
| `E_DUPLICATE_ID` | The same `id` appears twice in one CSV. |
| `E_SETTINGS_ROW_COUNT` | `settings.csv` does not have exactly one data row. |
| `E_COUNT_MISMATCH` | Data-row count disagrees with `manifest.row_counts`. |
| `E_NOT_CONFIRMED` | Typed keyword absent or incorrect while local history is non-empty. |
| `E_TXN_FAILED` | Any write, disk, or constraint failure. Transaction rolls back. |

**Warnings (non-fatal, surfaced in the confirm dialog or summary):** `W_UNKNOWN_ENTRY` (extra non-photo ZIP entry ignored) · `W_DIFFERENT_SOURCE_KEY` (`user_key_hash` differs from local — expected for device-to-device) · `W_SOURCE_HAD_PENDING_OUTBOX` (`outbox_pending_count > 0` in the source manifest) · `W_LOCAL_DATA_REPLACED` (row counts destroyed) · `W_QUEUE_DISCARDED` (outbox entries cleared) · `W_DRAFTS_DISCARDED` (drafts + photos purged for destroyed vehicles).

---

## Suggested layout

Mirror the `client/lib/export/` split so the pure parser stays testable without Drift:

```
client/lib/import/
  zip_read.dart      # central-directory reader, promoted from client/test/export/zip_read.dart
  csv_parse.dart     # BOM strip, RFC 4180, strict int/bool coercion
  validate.dart      # manifest gates, header check, per-column constraints → typed errors
  plan.dart          # parsed + validated rows, counts, warnings — no DB
  apply.dart         # replace: deletes, inserts, settings update, draft reconcile (one transaction)
  import_service.dart# file picker, inflate injection, post-commit file cleanup, orchestration
```

`headers.dart` is **imported from `client/lib/export/`**, never copied. Add a test asserting import's expected header set *is* the export constant set, so the two can never drift.

---

## Test expectations

Land in `client/test/import/` with a pointer row added to `tests/export/README.md` (or a sibling `tests/import/README.md`), matching how CES-41 mapped spec expectations to files.

1. **Golden round-trip** — export the CES-41 fixture, import into an empty DB, assert row-for-row equality on every canonical column. Under replace this is a complete correctness proof.
2. **Idempotency** — import the same ZIP twice; identical final state, no duplicate `id`s.
3. **Header strictness** — mutate one header cell → `E_HEADER_MISMATCH`, zero writes.
4. **Photo fail-closed** — inject `photos/x.jpg`; and separately set `photos_in_export: true` → `E_PHOTOS_PRESENT` both times, zero writes.
5. **Derived columns ignored** — corrupt `odometer_km` to a wrong value; assert the stored `odometer_m` still comes from the canonical cell.
6. **Cadence meters** — a rule with `cadence_km = 10000` stores `10000` (not `10`, not `10000000`).
7. **Value validation** — negative `volume_uL`, `1.0` in an INT column, bad `currency_code`, unknown `fuel_type`, unknown `category`, duplicate `id`: each rejects with the DB untouched.
8. **Atomicity** — induce a failure while writing the last table; assert the DB is byte-identical to before, including that pre-existing rows were *not* destroyed.
9. **Never-synced state** — imported rows have `row_version IS NULL`.
10. **FK orphan** — `fill_ups.vehicle_id` resolving nowhere in the ZIP → `E_FK_ORPHAN`.
11. **Module purity** — `csv_parse` / `validate` / `plan` import no Flutter, Drift, or `dart:io`, mirroring `client/test/export/module_purity_test.dart`.
12. **Streaming** — parse a ~1 000-row CSV without materializing every row at once, matching amendment **A4**'s posture (device timing is not a CI gate).

Replace-specific:

13. **Replace clears prior history** — seed a populated DB, import a disjoint ZIP, assert the four history tables contain exactly the ZIP's rows and none of the originals.
14. **`settings` updated in place** — `settings.id` unchanged; prefs adopted; `default_vehicle_id` set when the vehicle is in the ZIP and `NULL` when it is not.
15. **Outbox cleared** — seed pending entries, import, assert the outbox is empty and the summary reports the discarded count.
16. **Drafts reconciled** — a draft on a vehicle present in the ZIP survives with its `photo_refs` intact; a draft on a destroyed vehicle is removed along with its `photo_refs` rows, and its JPEG files are deleted after commit.
17. **Confirmation gate** — non-empty local history without the typed keyword → `E_NOT_CONFIRMED`, zero writes; empty local history imports without a keyword.

Not a CI gate, per A4: device timing on a large archive. Fold into the CES-68 manual pass.

---

## References

- [`export-v1.md`](export-v1.md) — export contract; § v1 amendments A1–A5 are the authoritative CSV shape.
- [`data-model.md`](data-model.md) — column types, constraints, protocol columns, client-only tables.
- [`si-units.md`](si-units.md) — canonical INT64 storage; derived columns are display-only.
- [`photo-pipeline.md`](photo-pipeline.md) — photo TTL, `photo_refs` → `drafts` relationship, why photos are absent from both directions.
- [`sync-protocol.md`](sync-protocol.md) — outbox / `row_version` semantics; § v1.x roadmap names this ticket.
- [ADR 002](adr/002-backup-sync-layer.md) — deferred field-level merge rules; the reason merge is not built here.
