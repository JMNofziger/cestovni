# Cursor execution prompt — CES-70 ZIP import

> **Status: BLOCKED — do not start.** One product lock is missing: **merge vs replace** (see [Decision 0](#decision-0--merge-vs-replace-missing)).
> Everything else is locked. When product answers, fill in Decision 0, flip this line to **READY**, and hand the file to Cursor unchanged.
> Linear **[CES-70](https://linear.app/personal-interests-llc/issue/CES-70)** — **Todo** → set **In Progress** when you start.
> Do **not** pick up M3 (CES-42–45), CES-51, CES-71, or PWA-lite unless the user explicitly redirects.

**Branch:** cut `cursor/ces-70-import-<suffix>` from **`main`**
**Spec (normative):** [`docs/specs/export-import.md`](../../specs/export-import.md) — read it end to end before writing code. It is executable; do not re-litigate its decisions.
**Also read:** [`docs/specs/export-v1.md`](../../specs/export-v1.md) § v1 amendments · [`docs/specs/data-model.md`](../../specs/data-model.md) · [`docs/specs/si-units.md`](../../specs/si-units.md) · [`client/lib/export/`](../../../client/lib/export/) · [`client/lib/photos/photo_export_guard.dart`](../../../client/lib/photos/photo_export_guard.dart) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-41** export — `client/lib/export/`, [PR #21](https://github.com/JMNofziger/cestovni/pull/21) |
| M1 | **Closed.** Log / History / Metrics / Maint / photos ship on Android |
| M2 | **CES-41 done.** This ticket is the import half |
| Prerequisite | **CES-41 must be merged to `main`** — import imports `client/lib/export/headers.dart` |
| Parallel (do not do here) | CES-63 iPhone install-doc · CES-68 APK · M3 CES-42–45 · CES-71 cadence rename |

**Git start:** `git fetch origin && git checkout -b cursor/ces-70-import-<suffix> origin/main`

---

## Goal

Settings → **Import data** ingests a ZIP the app produced itself, with zero server:

1. File picker → read the ZIP (central directory; STORE + DEFLATE)
2. Validate manifest, headers, and every canonical value — **no writes yet**
3. Confirm dialog: row counts, source vs local `user_key_hash`, mode
4. Apply in **one Drift transaction** in FK-parent order
5. Summary of rows written

**Invariant:** no photos, no drafts, no `photo_refs`, no outbox rows, `row_version` stays `NULL`, local `settings.id` untouched.

---

## Decision 0 — merge vs replace (MISSING)

> **Product: fill this in.** Spec § Open questions has both options, the recommendation (**replace**, behind a typed confirmation), and what breaks on a wrong guess.

```
MODE = <replace | merge>
```

Until this line names a mode, **stop and ask** — do not pick a default, and do not build both.

---

## Locked decisions (do not re-litigate)

All of these are normative in [`export-import.md`](../../specs/export-import.md). Implement as written; if one is genuinely unworkable, stop and comment on CES-70 rather than improvising.

1. **Reuse the export header constants.** Import `client/lib/export/headers.dart`; never copy or re-declare the strings. Add a test asserting import's expected header set *is* the export constant set.
2. **Strict headers.** Each CSV's first record must be byte-equal to its constant after BOM strip. Unknown extra **column** → reject. Unknown extra **ZIP entry** → ignore with a warning, except photo-shaped content, which fails closed.
3. **Canonical only.** Read `odometer_m`, `volume_uL`, `*_cents`, `tank_capacity_uL`, `cadence_km`. **Ignore** every derived column and every `*_local` timestamp — they must be present but are never read.
4. **`cadence_km` is meters, verbatim.** No conversion in either direction. The audit is clean (spec § Cadence units audit result); do not "fix" it, and do not rename it — that is CES-71.
5. **Photos fail closed.** `photos_in_export` must be `false`. Any `photos/` entry, image bytes, or `photo_refs.csv` aborts. Call `photo_export_guard.dart`; do not re-decide which paths are safe.
6. **Imported rows are never-synced.** `row_version = NULL`, `deleted_at = NULL`, `user_id` unset, `mutation_id` freshly generated, `updated_at` preserved from the CSV. **Enqueue nothing** to the outbox.
7. **`id`s preserved, never remapped.** Keeps repeat imports idempotent.
8. **Identity is advisory.** Differing `user_key_hash` is a warning shown in the confirm dialog, never a rejection. Never overwrite `settings.id`.
9. **FK order + orphan rejection.** Apply `vehicles → maintenance_rules → fill_ups → maintenance_events → settings`. Any `vehicle_id` / `rule_id` resolving nowhere → reject the whole import.
10. **Atomic.** One transaction. Any failure → full rollback, DB byte-identical.
11. **Settings prefs adopted**, `default_vehicle_id` only if that vehicle exists post-import, `settings.id` untouched.
12. **Foreground-only.** No background service, no notification, no new runtime permission (matches export A5).
13. **No odometer-regression re-validation.** The ZIP is accepted history; re-running entry-time validation would reject legitimate archives containing a reset.

---

## Scope (in)

1. `client/lib/import/` split per spec § Suggested layout — pure `csv_parse` / `validate` / `plan`, Drift only in `apply`, IO only in `import_service`.
2. Promote `client/test/export/zip_read.dart` into `client/lib/import/zip_read.dart` (central-directory reader; CES-41 sets the data-descriptor bit, so local-header sizes are zero). Add DEFLATE via an **injected** inflate callback so the parser stays pure.
3. Strict CSV coercion: BOM strip, CRLF **and** LF, RFC 4180, empty = null, booleans case-insensitive `true`/`false` only, integers reject `1.0` / grouping / `+5`.
4. Typed error codes per spec § Error handling, each carrying file + line + column where applicable.
5. Settings UI: **Import data** `LedgerTile` under **Export data**, confirm dialog, summary. Offer **Export data first** inline.
6. Tests per spec § Test expectations (items 1–14; item 15 unlocks with Decision 0) + a pointer row in `tests/export/README.md`.

## Scope (out)

- The CES-71 `cadence_km` → `cadence_m` rename
- M3 server / CES-42–45; any outbox enqueue for imported rows
- PWA-lite import · FX / CES-51 · telemetry emit
- Device timing as a CI gate (A4 — streaming test instead)
- Background import task (locked decision 12)

## Constraints

- Offline-first: import must work with zero network.
- No new schema migration. Canonical storage stays INT64.
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` all green.
- Cloud VM has no Android SDK — widget + fixture tests are the bar.

## Acceptance

- [ ] Golden round-trip: export fixture → import into empty DB → canonical columns equal row for row
- [ ] Importing the same ZIP twice changes nothing the second time
- [ ] Header mutation, photo-shaped content, and each value violation all reject with the DB untouched
- [ ] `drafts` / `photo_refs` / `outbox` counts unchanged; imported rows have `row_version IS NULL`
- [ ] `settings.id` unchanged; prefs adopted; `default_vehicle_id` validated
- [ ] Module purity + streaming tests present; no background-task code, no new permission
- [ ] Analyze + tests + telemetry gate green; delivery-plan M2 row updated
- [ ] Linear CES-70 Done + closeout comment; CES-71 unblocked

## Status report (required)

1. How the ZIP reader handles STORE vs DEFLATE and where the inflate is injected
2. Which mode Decision 0 resolved to, and what the confirm dialog shows
3. How header constants are shared with `client/lib/export/` and how the drift test asserts it
4. Error codes implemented vs spec § Error handling, and how partial-import is prevented
5. Tests added, including the streaming and module-purity proofs
6. Known limits — call out device timing as deferred to CES-68
7. PR URL + Linear CES-70 state

Tag: `CES-70 — ZIP import`.
