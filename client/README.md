# Cestovni — mobile client

**Stack:** Flutter + Drift (ADR 003).  
**Milestones:** M0 closed (CES-36, CES-37). **Android M1 closed** on `main` (`bb1d5d5`, 2026-08-16) — CES-38 math, CES-39 Log/History/vehicles, CES-57/65 prefs, CES-66 Metrics, CES-67 Maint, CES-40 photos. **CES-41 export** on `main`. **CES-70 import** implemented (Settings → Import data, `client/lib/import/`); spec tests green on PR #25, not on `main`. See [`docs/product/delivery-plan-v1.md`](../docs/product/delivery-plan-v1.md).

## Quick start

```bash
cd client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

## Layout

```
client/
  lib/
    main.dart
    app/
      app.dart                    # MaterialApp + CestovniTheme
      shell.dart                  # 4 tabs: Log / History / Metrics / Maint
      active_vehicle.dart         # session-scoped vehicle id
      pages/
        log_page.dart             # fill-up form + drafts (CES-39) + photos (CES-40)
        history_page.dart         # fuel + maint timeline (CES-39 / CES-67)
        vehicle_form_page.dart    # add/edit vehicle (CES-39)
        settings_page.dart        # vehicle CRUD + prefs (CES-57) + export/import
        import_data_section.dart  # CES-70 ZIP import (replace)
        metrics_page.dart         # aggregates + cost chart (CES-66)
        maintenance_page.dart     # maint entry + history (CES-67)
        debug_page.dart
      theme/                      # CES-55 visual system
    consumption/                  # CES-38 math + validation
    photos/                       # CES-40 receipt photo pipeline
    export/                       # CES-41 ZIP export (CSV + STORE zip + share)
    import/                       # CES-70 ZIP import (replace; spec tests in test/import/)
    metrics/                      # CES-66 aggregation
    maintenance/                  # CES-67 date-only + history ledger
    db/
      app_database.dart           # schema_version = 3
      repositories/               # vehicles, fill-ups, drafts, settings, photo refs
      migrations/
      tables/
  test/
    app/                          # log, history, settings, vehicle form widgets
    consumption/                  # golden fixtures + module purity
    photos/                       # EXIF strip, TTL, cleanup, no-upload invariant
    export/                       # ZIP golden, streaming, photos excluded
    import/                       # CES-70 spec § Test expectations
    db/
    shell_smoke_test.dart
```

## Spec alignment

- SI-INT64 columns per [`docs/specs/si-units.md`](../docs/specs/si-units.md).
- Protocol columns on backed-up tables (ADR 002).
- Fill-up save paths call `validateInsert` before `FillUpsRepository.create` / `amend`.
- Golden math fixtures: [`tests/math/`](../tests/math/) (20 JSON files, runner in `test/consumption/`).
- Receipt photos are on-device only per [`docs/specs/photo-pipeline.md`](../docs/specs/photo-pipeline.md):
  `client/lib/photos/` strips EXIF and enforces the TTL, `photo_refs` is absent
  from the outbox `table` CHECK, and `android:allowBackup="false"` keeps the
  sandbox out of OS backups. Manual device pass:
  [`docs/product/ces-40-manual-test.md`](../docs/product/ces-40-manual-test.md).

## CI

`ci/client-build.yml` — analyze, test, Android debug APK, iOS debug no-codesign.

`ci/telemetry-gate.py` check 2 scans `client/lib/**/*.dart` for allow-listed `Telemetry.emit` names.
