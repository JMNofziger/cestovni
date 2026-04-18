import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'migrations/migration_runner.dart';
import 'migrations/schema_steps.dart';
import 'tables/drafts.dart';
import 'tables/fill_ups.dart';
import 'tables/maintenance_events.dart';
import 'tables/maintenance_rules.dart';
import 'tables/outbox.dart';
import 'tables/photo_refs.dart';
import 'tables/settings.dart';
import 'tables/vehicles.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Vehicles,
  FillUps,
  MaintenanceRules,
  MaintenanceEvents,
  AppSettings,
  Drafts,
  Outbox,
  PhotoRefs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openOnDevice());

  /// Test constructor — inject an in-memory or file-backed executor.
  AppDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    final runner = MigrationRunner(schemaSteps(allTables));
    return MigrationStrategy(
      onCreate: (m) async {
        await runner.upgrade(m, 0, schemaVersion);
        await createIndexes();
      },
      onUpgrade: (m, from, to) async {
        await runner.upgrade(m, from, to);
        await createIndexes();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Exposed for tests and future rollback tooling (CES-47).
  MigrationRunner get migrationRunner =>
      MigrationRunner(schemaSteps(allTables));

  /// Indexes per docs/specs/data-model.md. Drift doesn't auto-create
  /// partial indexes from Dart tables, so we emit them once after the
  /// schema lands. Called from both `onCreate` and `onUpgrade` so the
  /// DB lands in the same state regardless of path.
  Future<void> createIndexes() async {
    const stmts = <String>[
      // vehicles
      'CREATE INDEX IF NOT EXISTS vehicles_user_id_idx ON vehicles (user_id)',
      'CREATE INDEX IF NOT EXISTS vehicles_user_live_idx ON vehicles (user_id) WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS vehicles_row_version_idx ON vehicles (row_version)',
      // fill_ups
      'CREATE INDEX IF NOT EXISTS fill_ups_user_vehicle_time_idx '
          'ON fill_ups (user_id, vehicle_id, filled_at DESC) '
          'WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS fill_ups_user_row_version_idx '
          'ON fill_ups (user_id, row_version)',
      'CREATE INDEX IF NOT EXISTS fill_ups_vehicle_id_idx ON fill_ups (vehicle_id)',
      // maintenance_rules
      'CREATE INDEX IF NOT EXISTS maintenance_rules_user_vehicle_idx '
          'ON maintenance_rules (user_id, vehicle_id) '
          'WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS maintenance_rules_user_row_version_idx '
          'ON maintenance_rules (user_id, row_version)',
      // maintenance_events
      'CREATE INDEX IF NOT EXISTS maintenance_events_user_vehicle_time_idx '
          'ON maintenance_events (user_id, vehicle_id, performed_at DESC) '
          'WHERE deleted_at IS NULL',
      'CREATE INDEX IF NOT EXISTS maintenance_events_user_row_version_idx '
          'ON maintenance_events (user_id, row_version)',
      // settings
      'CREATE UNIQUE INDEX IF NOT EXISTS settings_user_id_uidx ON settings (user_id)',
      'CREATE INDEX IF NOT EXISTS settings_row_version_idx ON settings (row_version)',
    ];
    for (final sql in stmts) {
      await customStatement(sql);
    }
  }
}

LazyDatabase _openOnDevice() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cestovni.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
