# Cestovni — mobile client

**Stack:** Flutter + Drift (ADR 003).
**Milestone:** M0 — Bootstrap + DB (CES-36 + CES-37).

## Quick start

```bash
cd client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

## Layout

```
client/
  lib/
    main.dart                     # entrypoint
    app/
      app.dart                    # MaterialApp + theme
      shell.dart                  # bottom nav: Home / Settings / Debug
      pages/                      # per-tab placeholders
    db/
      app_database.dart           # @DriftDatabase; schema_version = 1
      migrations/
        migration_runner.dart     # UP/DOWN step structure (CES-47 hook)
        schema_steps.dart         # 0001_init
      tables/                     # one file per v1 table
  test/
    db/                           # migration + round-trip + constraints + indexes
    shell_smoke_test.dart         # Home / Settings / Debug switchable
```

## Spec alignment

- Canonical SI-INT64 columns per [`docs/specs/si-units.md`](../docs/specs/si-units.md).
- Every backed-up table carries the ADR 002 protocol columns
  (`id`, `user_id`, `row_version`, `updated_at`, `deleted_at`,
  `mutation_id`) via the `ProtocolColumns` mixin.
- Indexes match [`docs/specs/data-model.md`](../docs/specs/data-model.md)
  and are verified by `test/db/indexes_test.dart`.
- Client-only tables (`drafts`, `outbox`, `photo_refs`) carry no
  protocol columns and are excluded from the outbox / export pipelines
  (M2 / M3 enforce that, not M0).

## CI

`ci/client-build.yml` — `test` + `android` + `ios` lanes; both platform
builds must be green before closing CES-36 per the acceptance checklist.

`ci/telemetry-gate.py` check 2 (client source scan) was activated by
CES-36: every literal `Telemetry.emit('name', …)` under `client/lib/`
is verified against `docs/specs/telemetry-events.v1.yaml`.
