# AGENTS.md

## Cursor Cloud specific instructions

This repo is **Cestovni**, an offline-first fuel/maintenance log. The runnable/testable
surfaces in this repo are: the Flutter Android client (`client/`), the iPhone PWA-lite
(`client/web-lite/`), and an in-memory Node dev sync stub (`server/dev-sync-stub/`).
There is no production backend, Postgres, or Docker Compose in the repo yet (M3+ is spec-only).

### Toolchain (already provisioned in the VM snapshot)

- **Flutter 3.41.7 / Dart 3.11.5** is installed at `$HOME/flutter` and on `PATH` via `~/.bashrc`.
  If `flutter` is not found in a non-interactive shell, use `$HOME/flutter/bin/flutter`.
- **Node 22**, **Python 3.12**, **JDK 21** are preinstalled. The Python telemetry-gate deps
  (`pyyaml`, `jsonschema`) are installed via the startup update script.
- **Native `libsqlite3`** (apt `libsqlite3-0`/`libsqlite3-dev`) is installed and required —
  the Dart `sqlite3` package used by Drift unit tests loads `libsqlite3.so` at runtime.
  Without it, all DB-backed tests fail with a `DynamicLibrary.open` error.

### Non-obvious caveats

- **Codegen is required before analyze/test.** Drift/build_runner outputs are cached in the
  gitignored `client/.dart_tool/` (not committed except `client/lib/db/app_database.g.dart`).
  Run `dart run build_runner build --delete-conflicting-outputs` in `client/` after pulling
  schema changes. The startup update script already does this.
- **Sync E2E test is skipped by default.** `client/test/sync/e2e_against_stub_test.dart`
  only runs with `CESTOVNI_E2E=1` AND the dev sync stub running on `:8787`. All other
  `flutter test` cases run headless with no server.
- **PWA-lite needs an HTTP origin** (service worker + IndexedDB won't work from `file://`).
  Serve `client/web-lite/` over HTTP, e.g. `python3 -m http.server 8080` from that dir.
- **PWA-lite empty state:** with no vehicle it shows "NO VEHICLES" and hides the log form.
  Append `?devseed=1` to the URL to seed a demo vehicle for local testing.
- **PWA-lite sync target:** `client/web-lite/config.js` points `apiBase` at
  `http://127.0.0.1:8787` (the dev stub). Default bearer token is `dev-cestovni-token`.

### Standard commands (see also `client/README.md`, `server/dev-sync-stub/README.md`, `ci/README.md`)

- Flutter client: `cd client && flutter analyze && flutter test --no-pub`
- Telemetry gate (CI parity): `python3 ci/telemetry-gate.py`
- Dev sync stub: `cd server/dev-sync-stub && node server.js` (contract test: `node contract.test.js`)
- Android APK build (`flutter build apk`) needs the Android SDK, which is **not** installed
  in the snapshot; it is only exercised in GitHub Actions `verify-full.yml`.
