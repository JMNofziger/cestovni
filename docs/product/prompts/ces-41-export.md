# Cursor execution prompt — CES-41 Export ZIP

> **Status: READY** (2026-08-16). Handoff after **CES-40** photos merged to `main` (PR #18).
> Linear **[CES-41](https://linear.app/personal-interests-llc/issue/CES-41)** — **Todo** → set **In Progress** when you start.
> Product direction: **do CES-41 next.** Do **not** pick up M3 (CES-42–45), CES-51, or PWA-lite unless the user explicitly redirects.

**Branch:** cut `cursor/ces-41-export-<suffix>` from **`main`**
**Linear:** [CES-41](https://linear.app/personal-interests-llc/issue/CES-41)
**Spec (normative):** [`docs/specs/export-v1.md`](../../specs/export-v1.md) — read **§ v1 amendments (2026-08-16)** first; it overrides the older CSV headers and the perf/background rows.
**Also read:** [`docs/specs/si-units.md`](../../specs/si-units.md) · [`docs/specs/photo-pipeline.md`](../../specs/photo-pipeline.md) §Export · [`client/lib/photos/photo_export_guard.dart`](../../../client/lib/photos/photo_export_guard.dart) · [`docs/product/delivery-plan-v1.md`](../delivery-plan-v1.md) §Current focus · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|--------|
| Last coding | **CES-40** photos + **CES-67** Maint — both **Done**, on `main` (`bb1d5d5`) |
| M1 | **Closed.** Log / History / Metrics / Maint / photos all ship on Android |
| Next coding | **This ticket (CES-41)** — first M2 vertical |
| Parallel (do not do here) | CES-63 iPhone install-doc · CES-68 APK · M3 CES-42–45 · CES-70 ZIP import |

**Git start:** `git fetch origin && git checkout -b cursor/ces-41-export-<suffix> origin/main`

---

## Goal

On-device ZIP export of structured data, per `export-v1.md`:

1. User taps Export (Settings is the natural home — no Export screen exists yet)
2. Optional outbox flush if online (fill-up gate slice already exists; do not fail the export if flush fails)
3. Stream `vehicles` / `fill_ups` / `maintenance_rules` / `maintenance_events` / `settings` into CSVs inside a ZIP
4. `manifest.json` + `README_export.txt`
5. **Invariant:** no drafts, no outbox rows, no `photo_refs`, no `photos/` bytes. Call `excludePhotoPaths` / `photosInExport` — do not re-decide.

No re-import (that's **CES-70**). No server. No PWA-lite.

---

## Already in the repo (do not recreate)

- Photo exclusion guard + test: `client/lib/photos/photo_export_guard.dart`, `client/test/photos/no_upload_invariant_test.dart`
- Display rounding: `client/lib/units/display_units.dart` (CES-65)
- Settings prefs: `SettingsRepository`
- Outbox flush worker (fill-ups only): `client/lib/sync/outbox_flush_worker.dart`
- No `archive` / ZIP package in `client/pubspec.yaml` yet

---

## Locked decisions (do not re-litigate)

Product/CTO calls made 2026-08-16, mirrored in `export-v1.md` § v1 amendments and on the Linear issue. Implement these as written; if one is genuinely unworkable, stop and comment on CES-41 rather than improvising.

### 1. CSV headers come from the live Drift schema

The spec's 2026-04 header list predates schema v2/v3. **The live schema decides which columns exist; the spec's order decides where they sit.** New columns append to the domain block, just before `notes`.

Three headers change from what the spec body shows:

- `maintenance_events.csv` — add `category`, `shop` after `currency_code` (CES-53, schema v2)
- `maintenance_rules.csv` — add `notes` before the audit columns (was never listed)
- `settings.csv` — add `default_vehicle_id` after `timezone` (CES-57, schema v3)

`vehicles.csv` and `fill_ups.csv` are unchanged. Copy the exact header strings from `export-v1.md` § A1; do not re-derive them.

Excluded from every CSV on purpose: `user_id` (`user_key_hash` stands in), `deleted_at` (soft-deleted rows are filtered, so it is always null), `mutation_id` (sync bookkeeping), and `settings.id` (equals the user id).

### 2. Both derived unit columns, always

Emit `odometer_km` **and** `odometer_mi`, `volume_L` **and** `volume_gal`, regardless of `settings` prefs. The header must not depend on user state — that keeps the golden-ZIP test stable and gives CES-70 one header to parse. `unit_preferences` in the manifest still records the user's actual preference.

### 3. `cadence_km` is meters

`maintenance_rules.cadence_km` holds **canonical meters** despite the name. Export it verbatim; add a `README_export.txt` line saying so. Do **not** rename it or add a converted column — that is a migration, and import has to round-trip the same header.

### 4. No 10k perf gate

Skip the 10 000-row / 30 s / 10 MB targets; they are device numbers and neither CI nor this VM can measure them. **Do build** a test that proves streaming: a chunk-observing or counting sink over a ~1 000-row fixture showing the assembler never holds every row or all CSV bytes at once. Note in the PR that device timing is deferred to the CES-68 manual pass.

### 5. Foreground-only export

No background service, no completion notification, no `POST_NOTIFICATIONS`. Show progress, keep the user on the screen. If the OS kills the app mid-export the `.tmp` is simply never renamed, which the atomicity contract already covers.

### 6. Manifest fields with no source yet

- `app_platform` — const `'android'`. PWA-lite has no export (ADR 005).
- `app_version` — prefer `package_info_plus`; if its platform channel makes widget tests awkward, use a single `const kAppVersion` next to the app entrypoint with a comment to bump it with `pubspec.yaml`. Either way **inject it** into the assembler so tests are deterministic.
- `user_key_hash` — telemetry is not wired (CES-46). Use the first 8 hex of SHA-256 over `settings.id` and document the stand-in in both the manifest section of the PR and `README_export.txt`.
- `row_version` / `max_row_version_seen` — the client never writes `row_version` before M3. CSV cell stays **empty**; manifest value is **`null`**. Do not synthesize a number.
- `outbox_pending_count` / `outbox_pending_hash` — compute for real from `OutboxRepository` per spec (count pending, SHA-256 over sorted `mutation_id`s, `null` hash when count is 0). In practice only fill-ups ever enqueue today; that is expected, not a bug.

---

## Scope (in)

1. **Pure-ish assembler** under `client/lib/export/` (same pattern as `photos/` / `metrics/`). Stream rows; do not buffer the whole ZIP in RAM.
2. **CSV rules** from the spec: UTF-8 with BOM, CRLF, RFC 4180 quoting, empty = null, booleans `true`/`false`, soft-deleted excluded, canonical INT64 + derived display columns. Headers per locked decision 1; both derived unit columns per locked decision 2.
3. **`manifest.json`:** `photos_in_export: false` hard-coded via the CES-40 constant. Everything with no clean source today — `app_version`, `app_platform`, `user_key_hash`, `max_row_version_seen`, the outbox pair — is settled in locked decision 6.
4. **Share:** write under the app sandbox then `share_plus` (or equivalent). Cloud VM has no Android SDK — widget + fixture tests are the bar.
5. **UI:** one Settings row "Export data" + a short "photos are not included" line. Reuse `LedgerTile` / `labelMono`. No new visual language.
6. **Tests:** fixture ZIP with known rows; assert the full CSV header strings + a few cells; `photos_in_export == false`; `excludePhotoPaths` still holds on the assembled file list; at least one test that a `photos/` JPEG is not inside the ZIP; plus the streaming test from locked decision 4. Prefer `client/test/export/` + a pointer in `tests/export/README.md`.

## Scope (out)

- ZIP **import** (**CES-70**)
- Production server / CES-42–45
- PWA-lite export
- FX / CES-51
- Telemetry emit
- 10k-row / 30 s / 10 MB perf gate (locked decision 4 — streaming test instead)
- Background export task + completion notification (locked decision 5)
- Renaming `cadence_km` to `cadence_m` (locked decision 3 — follow-up ticket)

## Constraints

- Offline-first: export must succeed with zero network (flush is best-effort).
- Canonical storage stays INT64; derived columns only in CSV.
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py`.
- Prefer no schema migration.

## Acceptance

- [ ] Settings → Export produces a ZIP with the spec file set
- [ ] Headers match `export-v1.md` § A1 exactly, including `category` / `shop` / `notes` / `default_vehicle_id`
- [ ] Manifest `photos_in_export: false`; ZIP contains zero JPEG/PNG
- [ ] Soft-deleted rows and drafts absent
- [ ] Streaming test present; no background-task code, no new runtime permission
- [ ] Analyze + tests green; delivery-plan CES-41 → 🟩; Current focus → **CES-70** import (or **CES-68** APK if product needs a demo sideload). Do **not** start CES-42–45 unless product redirects.
- [ ] Linear CES-41 Done + closeout comment

## Status report (required)

1. ZIP library chosen
2. Where the Export action lives
3. How `app_version` / `user_key_hash` / `row_version` were sourced
4. Tests added, including how the streaming test proves nothing is fully buffered
5. Known limits — call out device timing as deferred
6. PR URL + Linear CES-41 state

Tag: `CES-41 — Export ZIP`.
