# Cestovni — mobile client

**Stack:** Flutter + Drift (ADR 003).  
**Milestones:** M0 closed (CES-36, CES-37). M1 in progress — CES-38 consumption math **done**; CES-39 Log/History/vehicle UI **done on `main`**; CES-57 settings prefs + `default_vehicle_id` **done** (PR #9, schema v3). See [`docs/product/delivery-plan-v1.md`](../docs/product/delivery-plan-v1.md).

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
        log_page.dart             # fill-up form + drafts (CES-39)
        history_page.dart         # fill-up timeline (CES-39)
        vehicle_form_page.dart    # add/edit vehicle (CES-39)
        settings_page.dart        # vehicle CRUD + prefs (CES-57)
        metrics_page.dart         # stub
        maintenance_page.dart     # stub
        debug_page.dart
      theme/                      # CES-55 visual system
    consumption/                  # CES-38 math + validation
    db/
      app_database.dart           # schema_version = 3
      repositories/               # vehicles, fill-ups, drafts, settings
      migrations/
      tables/
  test/
    app/                          # log, history, settings, vehicle form widgets
    consumption/                  # golden fixtures + module purity
    db/
    shell_smoke_test.dart
```

## Spec alignment

- SI-INT64 columns per [`docs/specs/si-units.md`](../docs/specs/si-units.md).
- Protocol columns on backed-up tables (ADR 002).
- Fill-up save paths call `validateInsert` before `FillUpsRepository.create` / `amend`.
- Golden math fixtures: [`tests/math/`](../tests/math/) (20 JSON files, runner in `test/consumption/`).

## CI

`ci/client-build.yml` — analyze, test, Android debug APK, iOS debug no-codesign.

`ci/telemetry-gate.py` check 2 scans `client/lib/**/*.dart` for allow-listed `Telemetry.emit` names.
