# Cursor execution prompt — CES-40 Photo pipeline

> **Status: READY** (2026-08-15). Handoff after **CES-67** Maint shipped.
> Linear **[CES-40](https://linear.app/personal-interests-llc/issue/CES-40)** — Backlog → set **In Progress** when you start.
> Product direction: **do CES-40 next.** Do **not** pick up iPhone / CES-63 / PWA-lite unless the user explicitly redirects.

**Branch:** cut `cursor/ces-40-photos-<suffix>` from **CES-67 tip**, not stale `main`
**Linear:** [CES-40](https://linear.app/personal-interests-llc/issue/CES-40)
**Spec (normative):** [`docs/specs/photo-pipeline.md`](../../specs/photo-pipeline.md)
**Also read:** [`docs/specs/platform-compliance-v1.md`](../../specs/platform-compliance-v1.md) §receipt photos · [`docs/specs/data-model.md`](../../specs/data-model.md) client-only tables · [`docs/product/ux/DELIVERY_ACCEPTANCE.md`](../ux/DELIVERY_ACCEPTANCE.md) · [`docs/product/delivery-plan-v1.md`](../delivery-plan-v1.md) §Current focus · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|--------|
| Last coding ticket | **CES-67** Maint tab + History Maint — Linear **Done** |
| Branch / PR | `cursor/ces-67-maintenance-2aaa` — draft [PR #17](https://github.com/JMNofziger/cestovni/pull/17) (mergeable). **Not on `main` until merged.** |
| `origin/main` as of handoff | `131b3b8` (CES-65/66 only). Building CES-40 off that tip **drops Maint.** |
| Next coding | **This ticket (CES-40)** — last M1 vertical |
| Parallel (do not do here) | CES-63 iPhone ops · CES-68 APK · M2 export CES-41 · M3 CES-42–45 |

**Git start (required):**

1. `git fetch origin`
2. If PR #17 is **merged**, base off `origin/main`.
3. If PR #17 is **still open**, base off `origin/cursor/ces-67-maintenance-2aaa` (or merge that branch into yours). Do **not** re-implement Maint.
4. Cut a new feature branch. Cloud agents: `cursor/ces-40-photos-<run-suffix>`.
5. Linear CES-40 → **In Progress** + a one-line scope-lock comment (in / out below).

**Do not** delete or “clean up” the CES-67 branch until #17 is merged.

---

## Goal

Ephemeral **on-device** receipt photos for fill-up **drafts**, per `photo-pipeline.md`:

1. Capture / import → normalize → resize long-edge **1600 px** → JPEG q80 → **strip EXIF** (GPS + maker/serial) → SHA-256 → `photos/<uuid>.jpg` + `photo_refs` row
2. TTL cleanup: **30d from capture** or **7d after draft `completed_at`**, whichever is sooner
3. Discard draft / user delete → file + row **immediately**
4. Fill-up still works if camera permission is denied (never gate logging on a photo)
5. **Invariant:** photo bytes never in outbox payload, never uploaded, never in export

No OCR. Photos are memory aids, not parsed input.

---

## Already in the repo (do not recreate)

- Drift `photo_refs` — `client/lib/db/tables/photo_refs.dart` (CES-37). Client-only: **no** protocol columns, **not** in outbox `table` CHECK (`vehicles|fill_ups|maintenance_rules|maintenance_events|settings`).
- `drafts` + `DraftsRepository` — `client/lib/db/repositories/drafts_repository.dart`. One open draft per vehicle. `markCompleted` sets `completed_at` (needed for 7d TTL). `discard` **hard-deletes** the draft row — you **must** delete `photo_refs` + files **first** (FK to `drafts.id`, no cascade today).
- Log draft autosave — `client/lib/app/pages/log_page.dart` (`_saveDraftNow`). Attach photo should ensure a draft id exists (save draft first if `_draftId == null`).
- Round-trip test only: `client/test/db/roundtrip_test.dart` (`photo_refs` insert). **No** pipeline, cleanup, or UI yet. `tests/photos/` does **not** exist.
- No camera / image / EXIF packages in `client/pubspec.yaml` yet.
- **No `Telemetry.emit` in the client.** Do **not** add `photo_capture` / `had_photo` emits in this PR (M4 / CES-46). Allowlist already has the events — wiring later. `python3 ci/telemetry-gate.py` must stay green.

---

## Scope (in)

### Phase 1 — Pipeline + repository + cleanup (testable without a camera)

Pure-ish library + Drift. Prefer `client/lib/photos/` (same pattern as `client/lib/maintenance/` / `client/lib/metrics/`).

1. **Process bytes:** orientation from EXIF → resize long-edge 1600 → JPEG 80 → strip GPS + serial / maker notes → SHA-256 hex → byte size.
2. **EXIF library:** use a maintained Dart/Flutter package — **do not** write a parser. Name the package + why in the PR. If nothing credible, stop and comment on CES-40 before coding.
3. **`PhotoRefsRepository`:** insert/list-by-draft/delete; max **5** photos per draft (throw or return a typed error the UI can show). Persist `captured_at` (EXIF time UTC, else device clock) and `ttl_expires_at = captured_at + 30d`.
4. **Sandbox path:** `<app-docs>/photos/<id>.jpg` via `path_provider`. Tests use a temp dir injected into the repo (do not hit a real camera).
5. **Cleanup job** (`photo-pipeline.md` §Cleanup):
   - Delete **file first**, then row (crash-safe).
   - Purge if `ttl_expires_at <= now`.
   - On fill-up complete: set `ttl_expires_at = min(now+7d, existing ttl)`.
   - Orphan row (missing file) → drop row; orphan file without row → delete file on scan if cheap, else document follow-up.
   - Hook: app start / Log page `initState` is enough for v1 (throttle once/hour in memory). Skip OS `onTrimMemory` if it fights the test VM.
6. **Draft discard:** extend `DraftsRepository.discard` (or a coordinator) so photos are removed before the draft row.

**Tests (required):**

- EXIF strip: fixture JPEG **with GPS**; output has no GPS/maker; `captured_at` preserved or falls back. Put fixtures under `tests/photos/fixtures/` (spec) **or** `client/test/photos/fixtures/` if easier for `flutter test` — if you use `client/test`, add a one-line pointer in `tests/photos/README.md`.
- TTL: seed `now-29d` (keep), `now-31d` (purge), completed `now-8d` with shortened 7d TTL (purge).
- Orphan row: delete file, run cleanup, row gone, no throw.
- Five-photo cap.
- Discard draft deletes files + rows.
- SHA-256 / `byte_size` match written file.

### Phase 2 — Log UI (attach / preview / delete)

1. On Log (`log_page.dart`), optional **Attach photo** (camera + library). Match existing tokens (`LedgerCard`, hairline, `labelMono`) — no new visual language. Screenshot spirit: `docs/product/ux/screenshots/dark-midnight/log.png`.
2. Thumbnails on the draft; tap → full preview + Delete.
3. At 5 photos, disable add with a short explanation.
4. Permission denied: hide/disable attach; **form still saves**. Never block fill-up on camera.
5. Completing a fill-up shortens TTL (Phase 1); do not keep showing a live thumbnail on History after purge. Grey “had a receipt” icon on completed fill-ups is **nice-to-have** if a cheap local flag exists; otherwise skip (spec UX rule, not Linear must-have). Do **not** add a `fill_ups` column without a migration + product OK.
6. First-run hint once: photos stay on this device, not backed up, not in export (`platform-compliance-v1.md` §3). Settings → Privacy copy can wait if Settings has no Privacy section yet — one Log hint is enough.

**Widget tests:** fake picker / inject already-processed bytes (Cloud VM has **no Android SDK**, no camera). Cover: attach appears after draft save; cap at 5; delete removes thumbnail; permission-off still shows Save.

### Phase 3 — Invariants + docs + board

1. **Never in outbox:** test that completing a fill-up with photos does not put JPEG/base64 in `outbox.payload_json`. Schema already forbids `photo_refs` as an outbox `table`.
2. **Export exclusion:** CES-41 ZIP is **not** built. Add a small helper or comment + test that a future export file list would not include `photos/`. Do **not** implement export.
3. Docs: `delivery-plan-v1.md` CES-40 → 🟩; Current focus → next spine item (**CES-41** export, unless product says CES-68 APK). Update `cestovni-views.md` Log note, `DELIVERY_ACCEPTANCE.md` / `UX_IMPLEMENTATION_GAPS.md` headers (M1 photos closed). Mark this prompt **EXECUTED**.
4. Linear CES-40 **Done** + closeout comment (package choice, test counts, known limits). Comment on parent **CES-35**.

---

## Scope (out)

- OCR
- PWA-lite / `client/web-lite/` photos
- iPhone install (CES-63), Android APK (CES-68)
- Upload, outbox, or server photo endpoints
- ZIP export implementation (CES-41) — exclusion **test/helper only**
- `Telemetry.emit` (`photo_capture`, `had_photo`) — M4
- Maint-tab photos
- Multi-device photo restore (v1: local only, expected loss on new phone)

---

## Constraints

- Offline-only. Bytes stay in the app sandbox.
- Disable OS backup for `photos/` if the platform API is straightforward (Android backup rules / iOS protection). If not, document the gap in the PR — do not block the pipeline on it.
- Canonical DB unchanged except `photo_refs` writes. **Prefer no schema migration.** If you need a `had_photo` flag on `fill_ups`, ask in the PR rather than sneaking a v4 migration.
- `cd client && flutter analyze && flutter test --no-pub` + `python3 ci/telemetry-gate.py`.
- Codegen only if schema changes: `dart run build_runner build --delete-conflicting-outputs`.
- Cloud VM: no `flutter build apk`; widget + fixture tests are the acceptance bar.

---

## Likely touchpoints

| Path | Role |
|------|------|
| `docs/specs/photo-pipeline.md` | Normative lifecycle, EXIF list, TTL, tests |
| `client/lib/db/tables/photo_refs.dart` | Existing table |
| `client/lib/db/repositories/drafts_repository.dart` | Discard / complete ordering vs photos |
| `client/lib/app/pages/log_page.dart` | Attach UI |
| new `client/lib/photos/` | Process + cleanup |
| new `client/lib/db/repositories/photo_refs_repository.dart` | CRUD |
| `client/pubspec.yaml` | EXIF + image_picker (or equivalent) |
| `client/test/photos/` + `tests/photos/fixtures/` | Strip / TTL / orphan |
| `docs/product/delivery-plan-v1.md` | RYG + Current focus |

---

## Acceptance criteria

- [ ] Capture/import path writes stripped JPEG + `photo_refs` (camera + library on device; fake source in tests)
- [ ] EXIF GPS/maker stripped in memory; only UTC capture time in metadata
- [ ] TTL 30d capture / 7d post-complete; discard deletes immediately
- [ ] ≤5 photos/draft; fill-up works without camera permission
- [ ] Test: photo bytes never in outbox payload
- [ ] `flutter analyze` + `flutter test --no-pub` green; telemetry-gate PASS
- [ ] Docs + Linear CES-40 Done

---

## Validation

```bash
cd client
flutter analyze
flutter test --no-pub
python3 ../ci/telemetry-gate.py
```

Manual (device/emulator with camera — skip on Cloud VM, say so in the status report):

1. New fill-up draft → attach from camera and from library → thumbnails show.
2. Confirm output file has no GPS (any EXIF viewer).
3. Delete one photo; discard draft → files gone from sandbox.
4. Complete fill-up → still no photo in DB outbox rows.
5. Deny camera permission → Log still saves.

---

## Status report (required at end of run)

1. Base git ref (PR #17 merged or not)
2. Files changed
3. EXIF/image packages chosen
4. Where cleanup is triggered
5. Tests added + commands run
6. Known limits (backup-disable, History icon, telemetry deferred)
7. PR URL + Linear CES-40 state

Tag: `CES-40 — Photo pipeline`.
