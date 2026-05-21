# Cursor prompt: PWA offline spike (execute now)

Copy everything below the line into a **new Cursor agent chat** on branch `spike/pwa-offline` (or similar).

---

## Context

Cestovni is a Flutter + Drift offline-first fuel log app. **ADR 005** defers the App Store ($99/yr) and commits to:

- **Android:** native APK (existing `client/android/`)
- **iPhone:** installable **Flutter web PWA** — only if this spike passes

Docs are in place:

- [`docs/specs/adr/005-distribution-channels.md`](../../specs/adr/005-distribution-channels.md)
- [`docs/specs/spike-pwa-offline.md`](../../specs/spike-pwa-offline.md) — fill in results when done
- [`docs/specs/adr/003-mobile-stack.md`](../../specs/adr/003-mobile-stack.md) — web allowed as iOS channel with deltas

**Do not** wire Glitchtip, export ZIP, or production CI web jobs in this spike unless needed to compile.

## Your mission

Timebox **3–5 days**. Deliver a spike branch that:

1. **Compiles** `flutter build web` from `client/`.
2. **Runs** on Safari iOS 17+ as an installed PWA with offline fill-up persistence (see acceptance tests).
3. **Documents** GO / GO-with-limits / NO-GO in [`docs/specs/spike-pwa-offline.md`](../../specs/spike-pwa-offline.md).

## Hard technical tasks (in order)

### 1. Enable web + dependencies

```bash
cd client
flutter config --enable-web
```

In [`client/pubspec.yaml`](../../client/pubspec.yaml):

- Add `drift_flutter` (WASM + OPFS executor for web).
- Keep `sqlite3_flutter_libs` for Android; use conditional imports or `drift_flutter` unified open if docs recommend.

Run `flutter pub get`.

### 2. Platform-conditional database open (critical)

[`client/lib/db/app_database.dart`](../../client/lib/db/app_database.dart) currently:

- imports `dart:io`
- uses `NativeDatabase.createInBackground` + `path_provider`

Refactor to a pattern like:

- `app_database_native.dart` — existing `LazyDatabase` + `NativeDatabase` (mobile/desktop)
- `app_database_web.dart` — `drift_flutter` WASM + OPFS (see Drift docs: web database setup)
- `app_database.dart` — exports `AppDatabase`, uses conditional import for `openConnection()`

`AppDatabase()` constructor must call the shared `openConnection()` without `dart:io` on web.

**Preserve:** `schemaVersion` 2, `MigrationStrategy`, `createIndexes()`, existing tests on VM/native.

Add at least one **web-targeted** test or smoke if feasible; native `client/test/db/` must stay green.

### 3. First web build

```bash
cd client
dart run build_runner build --delete-conflicting-outputs
flutter build web
```

Fix compile errors from any other `dart:io` imports under `client/lib/` (grep `dart:io`, `Platform.`, `path_provider` in non-DB code). Use `kIsWeb` guards only where necessary — prefer conditional imports for DB.

### 4. PWA shell (minimal)

Under `client/web/` (generated or edited):

- `index.html`: link `manifest.json`, theme-color, **`mobile-web-app-capable`** (W3C; do not rely on deprecated `apple-mobile-web-app-capable` alone).
- `manifest.json`: `name`, `short_name`, `display: standalone`, icons (can be placeholders).
- `_headers` for Cloudflare Pages preview:

```text
/*
  Service-Worker-Allowed: /
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Opener-Policy: same-origin
```

Deploy preview to **Cloudflare Pages** (or local HTTPS tunnel if needed for iPhone). GitHub Pages is **not** suitable (no custom headers).

### 5. Manual acceptance on iPhone

Follow [`docs/specs/spike-pwa-offline.md`](../../specs/spike-pwa-offline.md) tests **T1–T4** (T5 optional). Use Debug page or minimal UI to insert one vehicle + one fill-up if CES-39 UI is not ready.

Record: iOS version, Safari version, pass/fail per test.

### 6. Camera + OPFS (scope only)

If `image_picker` or equivalent works on web: attempt one capture and OPFS write. **Do not** implement full [`photo-pipeline.md`](../../specs/photo-pipeline.md) unless trivial. Record decision: `full` | `limited` | `deferred` in spike doc.

## Explicit non-goals

- No App Store / `client/ios` distribution work.
- No changes to [`ci/paused/verify-ios-weekly.yml`](../../ci/paused/verify-ios-weekly.yml).
- No Glitchtip / `sentry_flutter` wiring.
- No `verify-full.yml` web CI job yet (follow-up after GO).
- No production Android APK release pipeline (parallel track).

## Status report format (required in chat when done)

```markdown
## PWA offline spike — status

**Verdict:** GO | GO-with-limits | NO-GO

**Branch / commit:**

**Files changed (max 10 bullets):**

**Commands run:**

**T1–T4 results:** (table)

**Photo pipeline decision:** full | limited | deferred

**Blockers / follow-ups:**

**Updated:** docs/specs/spike-pwa-offline.md (yes/no)
```

## Key file references

| Area | Path |
|------|------|
| DB entry | `client/lib/db/app_database.dart` |
| Schema | `client/lib/db/migrations/`, `schema_version` 2 |
| Main | `client/lib/main.dart` |
| ADR distribution | `docs/specs/adr/005-distribution-channels.md` |
| Spike results | `docs/specs/spike-pwa-offline.md` |

## If NO-GO

Still commit spike doc with failures. Do not merge platform-conditional DB to `main` without product ack. Android native work continues unaffected.
