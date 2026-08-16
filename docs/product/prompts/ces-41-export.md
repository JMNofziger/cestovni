# Cursor execution prompt — CES-41 Export ZIP

> **Status: READY** (2026-08-16). Handoff after **CES-40** photos merged to `main` (PR #18).
> Linear **[CES-41](https://linear.app/personal-interests-llc/issue/CES-41)** — **Todo** → set **In Progress** when you start.
> Product direction: **do CES-41 next.** Do **not** pick up M3 (CES-42–45), CES-51, or PWA-lite unless the user explicitly redirects.

**Branch:** cut `cursor/ces-41-export-<suffix>` from **`main`**
**Linear:** [CES-41](https://linear.app/personal-interests-llc/issue/CES-41)
**Spec (normative):** [`docs/specs/export-v1.md`](../../specs/export-v1.md)
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

## Scope (in)

1. **Pure-ish assembler** under `client/lib/export/` (same pattern as `photos/` / `metrics/`). Stream rows; do not buffer the whole ZIP in RAM.
2. **CSV rules** from the spec: UTF-8 with BOM, CRLF, RFC 4180 quoting, empty = null, booleans `true`/`false`, soft-deleted excluded, canonical INT64 + derived display columns.
3. **`manifest.json`:** `photos_in_export: false` hard-coded via the CES-40 constant. `user_key_hash`: telemetry is not wired (CES-46) — use a stable local stand-in (e.g. SHA-256 of `settings.id` truncated to 8 hex) and document it. `row_version` is null on the client until M3 — export empty, do not invent.
4. **Share:** write under the app sandbox then `share_plus` (or equivalent). Cloud VM has no Android SDK — widget + fixture tests are the bar.
5. **UI:** one Settings row "Export data" + a short "photos are not included" line. Reuse `LedgerTile` / `labelMono`. No new visual language.
6. **Tests:** fixture ZIP with known rows; assert CSV headers + a few cells; `photos_in_export == false`; `excludePhotoPaths` still holds on the assembled file list; at least one test that a `photos/` JPEG is not inside the ZIP. Prefer `client/test/export/` + a pointer in `tests/export/README.md`.

## Scope (out)

- ZIP **import** (**CES-70**)
- Production server / CES-42–45
- PWA-lite export
- FX / CES-51
- Telemetry emit
- 10k-row heap test if it needs a device profiler — a streaming unit test that never holds all CSV bytes at once is enough; document if you skip the 10k fixture

## Constraints

- Offline-first: export must succeed with zero network (flush is best-effort).
- Canonical storage stays INT64; derived columns only in CSV.
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py`.
- Prefer no schema migration.

## Acceptance

- [ ] Settings → Export produces a ZIP with the spec file set
- [ ] Manifest `photos_in_export: false`; ZIP contains zero JPEG/PNG
- [ ] Soft-deleted rows and drafts absent
- [ ] Analyze + tests green; delivery-plan CES-41 → 🟩; Current focus → **CES-70** import (or **CES-68** APK if product needs a demo sideload). Do **not** start CES-42–45 unless product redirects.
- [ ] Linear CES-41 Done + closeout comment

## Status report (required)

1. ZIP library chosen
2. Where the Export action lives
3. How `user_key_hash` / `row_version` were handled
4. Tests added
5. Known limits
6. PR URL + Linear CES-41 state

Tag: `CES-41 — Export ZIP`.
