# Cursor execution prompt — CES-70 ZIP import

> **Status: READY** (2026-08-16). All product locks resolved — **mode is `replace`**.
> Prerequisite: **CES-41 must be merged to `main`** first; import shares `client/lib/export/headers.dart`.
> Linear **[CES-70](https://linear.app/personal-interests-llc/issue/CES-70)** — **Todo** → set **In Progress** when you start.
> Do **not** pick up M3 (CES-42–45), CES-51, CES-71, or PWA-lite unless the user explicitly redirects.

**Branch:** cut `cursor/ces-70-import-<suffix>` from **`main`**
**Spec (normative):** [`docs/specs/export-import.md`](../../specs/export-import.md) — read it end to end before writing code. It is complete; do not re-litigate its decisions.
**Also read:** [`docs/specs/export-v1.md`](../../specs/export-v1.md) § v1 amendments · [`docs/specs/data-model.md`](../../specs/data-model.md) · [`docs/specs/si-units.md`](../../specs/si-units.md) · [`docs/specs/photo-pipeline.md`](../../specs/photo-pipeline.md) · `client/lib/export/` · [`client/lib/photos/photo_export_guard.dart`](../../../client/lib/photos/photo_export_guard.dart) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-41** export — `client/lib/export/`, [PR #21](https://github.com/JMNofziger/cestovni/pull/21) |
| M1 | **Closed.** Log / History / Metrics / Maint / photos ship on Android |
| M2 | **CES-41 done.** This ticket is the import half |
| Prerequisite | **CES-41 on `main`** — import imports `client/lib/export/headers.dart`, never copies it |
| Parallel (do not do here) | CES-63 iPhone install-doc · CES-68 APK · M3 CES-42–45 · CES-71 cadence rename |

**Git start:** `git fetch origin && git checkout -b cursor/ces-70-import-<suffix> origin/main`

---

## Goal

Settings → **Import data** replaces local history from a ZIP the app produced itself, with zero server:

1. File picker → read the ZIP (central directory; STORE + DEFLATE)
2. Validate manifest, headers, and every canonical value — **no writes yet**
3. Confirm dialog: what comes in, what gets destroyed, source vs local `user_key_hash`, typed keyword when there is data to lose
4. Apply **replace** in **one Drift transaction**
5. Delete purged photo files after commit; show a summary

**Invariant:** no photos in, `row_version` stays `NULL`, no outbox enqueue, local `settings.id` never overwritten, and either a valid new state exists or the DB is byte-identical to before.

---

## Locked decisions (do not re-litigate)

All normative in [`export-import.md`](../../specs/export-import.md). Implement as written; if one is genuinely unworkable, stop and comment on CES-70 rather than improvising.

### 0. Mode is `replace`

```
MODE = replace
```

Make local history match the archive. **Do not build merge**, do not stub it, do not make it selectable. Rationale is in spec § Product decisions — the short version is that export omits soft-deleted rows, so a merge can never delete anything and would resurrect every row the user deleted on the source device.

### Per-table disposition (spec § Replace semantics)

1. `vehicles` / `fill_ups` / `maintenance_rules` / `maintenance_events` — **hard `DELETE`, then insert from the ZIP.** Not soft-delete: leftover rows would collide on the primary key.
2. `settings` — **`UPDATE` in place, never deleted.** Deleting destroys `settings.id`. Adopt units/currency/timezone; `default_vehicle_id` only if that vehicle is in the ZIP, else `NULL`.
3. `outbox` — **cleared.** Every row describes a mutation on one of the four replaced tables (the `table` CHECK guarantees it). Report the discarded count.
4. `drafts` — **preserved when the draft's `vehicle_id` is present in the ZIP; discarded when it is not.** Drafts are looked up by vehicle (`DraftsRepository.openDraftForVehicle`), so a draft whose vehicle is gone is unreachable and would resurface if that vehicle id ever returned.
5. `photo_refs` + JPEGs — **follow `drafts`.** `photo_refs.draft_id` is an FK to `drafts`, **not** `fill_ups`, and `ttl_expires_at` is absolute, so replacing fill-ups orphans nothing. Only a discarded draft's photos are purged.

### Ordering (all DB work in one transaction)

Validate → `DELETE` children before parents (`maintenance_events` → `fill_ups` → `maintenance_rules` → `vehicles`) → clear `outbox` → insert parents before children (`vehicles` → `maintenance_rules` → `fill_ups` → `maintenance_events`) → `UPDATE settings` → reconcile `drafts` (delete `photo_refs` rows before draft rows; `photo_refs.draft_id` has no `ON DELETE CASCADE`).

**Delete photo files only after the transaction commits.** An interruption then leaves files with no row, which `PhotoService.sweep` already collects as `orphanFilesDeleted`. Deleting files first would leave rows pointing at missing files on rollback.

### The rest

6. **Reuse the export header constants.** Import `client/lib/export/headers.dart`; never copy or re-declare the strings. Add a test asserting import's expected header set *is* the export constant set.
7. **Strict headers.** Each CSV's first record byte-equal to its constant after BOM strip. Unknown extra **column** → reject. Unknown extra **ZIP entry** → ignore with a warning, except photo-shaped content, which fails closed.
8. **Canonical only.** Read `odometer_m`, `volume_uL`, `*_cents`, `tank_capacity_uL`, `cadence_km`. **Ignore** every derived column and every `*_local` timestamp — they must be present but are never read.
9. **`cadence_km` is meters, verbatim.** No conversion either direction. The audit is clean (spec § Cadence units audit result); do not "fix" it and do not rename it — that is CES-71.
10. **Photos fail closed.** `photos_in_export` must be `false`. Any `photos/` entry, image bytes, or `photo_refs.csv` aborts. Call `photo_export_guard.dart`; do not re-decide which paths are safe.
11. **Imported rows are never-synced.** `row_version = NULL`, `deleted_at = NULL`, `user_id` unset, `mutation_id` freshly generated, `updated_at` preserved from the CSV. **Enqueue nothing.**
12. **`id`s preserved, never remapped.** Duplicate `id` within one CSV → reject.
13. **FK integrity resolves within the ZIP only** — there is no "already live locally" fallback under replace. Unresolvable `vehicle_id` / `rule_id` → reject the whole import.
14. **Identity is advisory.** Differing `user_key_hash` is a warning shown in the confirm dialog, never a rejection. Never overwrite `settings.id`.
15. **Confirmation.** Local history non-empty → require typing `REPLACE` exactly, and offer **Export current data first** inline. Local history empty → plain confirm, no keyword, no export offer. **No undo** either way.
16. **Foreground-only.** No background service, no notification, no new runtime permission (matches export A5).
17. **No odometer-regression re-validation.** The ZIP is accepted history; re-running entry-time rules would reject legitimate archives containing a reset.

---

## Scope (in)

1. `client/lib/import/` split per spec § Suggested layout — pure `csv_parse` / `validate` / `plan`, Drift only in `apply`, IO only in `import_service`.
2. Promote `client/test/export/zip_read.dart` into `client/lib/import/zip_read.dart` (central-directory reader; CES-41 sets the data-descriptor bit, so local-header sizes are zero). Add DEFLATE via an **injected** inflate callback so the parser stays pure.
3. Strict CSV coercion: BOM strip, CRLF **and** LF, RFC 4180, empty = null, booleans case-insensitive `true`/`false` only, integers reject `1.0` / grouping / `+5`.
4. Typed error codes per spec § Error handling (17 codes), each carrying file + line + column where applicable, plus the six warning codes.
5. Settings UI: **Import data** `LedgerTile` under **Export data**; confirm dialog showing incoming counts, destroyed counts, discarded queue count, affected drafts, both hashes, and the typed field when needed; summary afterwards. User-facing wording is drafted in spec § User-facing explanation — reuse it, do not invent new copy.
6. Tests per spec § Test expectations (all 17).

## Scope (out)

- **Merge mode** in any form
- The CES-71 `cadence_km` → `cadence_m` rename
- M3 server / CES-42–45; any outbox enqueue for imported rows
- PWA-lite import · FX / CES-51 · telemetry emit
- Device timing as a CI gate (A4 — streaming test instead)
- Background import task · schema migration · i18n of the typed keyword

## Constraints

- Offline-first: import must work with zero network.
- No new schema migration. Canonical storage stays INT64.
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` all green.
- Cloud VM has no Android SDK — widget + fixture tests are the bar.

## Acceptance

- [ ] Golden round-trip: export fixture → import into empty DB → canonical columns equal row for row
- [ ] Importing the same ZIP twice yields identical state (idempotent, no duplicate `id`s)
- [ ] Replace clears prior history: populated DB + disjoint ZIP → exactly the ZIP's rows remain
- [ ] `settings` updated in place, `settings.id` unchanged, prefs adopted, `default_vehicle_id` validated
- [ ] Outbox cleared with the discarded count reported
- [ ] Drafts reconciled: surviving vehicle keeps draft + photos; destroyed vehicle purges both, files deleted post-commit
- [ ] Typed keyword enforced when local history is non-empty, skipped when empty
- [ ] Header mutation, photo-shaped content, duplicate id, FK orphan, and each value violation reject with the DB untouched
- [ ] Imported rows have `row_version IS NULL`; nothing enqueued
- [ ] Atomicity: an induced mid-write failure leaves pre-existing rows intact
- [ ] Module-purity + streaming tests present (device timing deferred to CES-68 per export A4)
- [ ] `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` green
- [ ] `delivery-plan-v1.md` M2 row + Current focus updated; CES-71 unblocked
- [ ] Linear CES-70 Done + closeout comment

## Status report (required)

1. How the ZIP reader handles STORE vs DEFLATE and where the inflate is injected
2. Confirm-dialog contents and how the typed-keyword gate is bypassed on an empty DB
3. How header constants are shared with `client/lib/export/` and how the drift test asserts it
4. Draft/photo reconcile: how post-commit file deletion stays crash-safe
5. Error + warning codes implemented vs spec, and how partial import is prevented
6. Tests added, including the streaming and module-purity proofs
7. Known limits — call out device timing as deferred to CES-68
8. PR URL + Linear CES-70 state

Tag: `CES-70 — ZIP import`.
