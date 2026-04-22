import 'package:drift/drift.dart';

import 'migration_runner.dart';

/// Ordered list of schema migration steps. Numbers align with the server
/// migration filenames under `db/migrations/NNNN_*.sql` per
/// docs/specs/data-model.md §"Migration alignment (client ↔ server)".
///
/// Each step is forward-only at runtime in v1 (`down` is a hook for
/// CES-47 rollback tooling).
List<MigrationStep> schemaSteps(Iterable<TableInfo> allTables) {
  final tablesInOrder = allTables.toList(growable: false);
  final maintenanceEventsTable = allTables.firstWhere(
    (t) => t.actualTableName == 'maintenance_events',
  );
  return [
    MigrationStep(
      from: 0,
      to: 1,
      name: '0001_init',
      up: (m) async {
        for (final t in tablesInOrder) {
          await m.createTable(t);
        }
      },
      // Drift is forward-only in v1. `down` is wired so M5 rollback
      // tooling (CES-47) has a concrete hook to drive from a
      // "hard reset + restore" Settings flow (data-model.md §"Client
      // schema migration rollback"). Dropping in reverse order
      // satisfies the FK constraints.
      down: (m) async {
        for (final t in tablesInOrder.reversed) {
          await m.deleteTable(t.actualTableName);
        }
      },
    ),
    MigrationStep(
      from: 1,
      to: 2,
      name: '0002_add_maintenance_events_category_shop',
      // Closes CES-53 — see docs/specs/data-model.md §maintenance_events
      // and docs/product/ux/DATA_CONTRACTS.md §Maintenance.
      //
      // Two in-place ALTERs + one table rebuild:
      //   1. add `category` (NOT NULL DEFAULT 'other' + CHECK enum)
      //   2. add `shop` (NULL + length CHECK)
      //   3. rebuild `maintenance_events` to relax odometer_m NOT NULL
      //      (SQLite can't DROP NOT NULL in-place).
      //
      // The rebuild reuses Drift's generated CREATE TABLE via
      // `m.createTable(maintenanceEventsTable)` so the post-migration
      // schema is byte-identical to a fresh `onCreate` install.
      // Partial indexes are recreated by `AppDatabase.createIndexes()`
      // which `onUpgrade` runs right after this step.
      up: (m) async {
        await m.database.customStatement(
          "ALTER TABLE maintenance_events "
          "ADD COLUMN category TEXT NOT NULL DEFAULT 'other' "
          "CHECK (category IN "
          "('oil','tires','brakes','inspection','battery','fluid','other'))",
        );
        await m.database.customStatement(
          'ALTER TABLE maintenance_events '
          'ADD COLUMN shop TEXT NULL '
          'CHECK (shop IS NULL OR length(shop) BETWEEN 1 AND 120)',
        );

        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _maintenance_events_backup AS '
          'SELECT * FROM maintenance_events',
        );
        await m.deleteTable('maintenance_events');
        await m.createTable(maintenanceEventsTable);
        // Explicit column list so a future column-add does not silently
        // mis-align the copy (SQLite allows SELECT * to reorder after a
        // rebuild).
        await m.database.customStatement(
          'INSERT INTO maintenance_events ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, rule_id, performed_at, odometer_m, cost_cents, '
          'currency_code, category, shop, notes'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, rule_id, performed_at, odometer_m, cost_cents, '
          'currency_code, category, shop, notes '
          'FROM _maintenance_events_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _maintenance_events_backup',
        );
      },
      // Rollback hook for CES-47 — reverses the forward step by
      // rebuilding with the v1 shape (no category / shop; odometer_m
      // NOT NULL). Rows where odometer_m IS NULL become 0 on downgrade
      // (acceptable trade-off for pre-production data; see
      // docs/specs/data-model.md §"Client schema migration rollback").
      down: (m) async {
        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _maintenance_events_backup AS '
          'SELECT * FROM maintenance_events',
        );
        await m.deleteTable('maintenance_events');
        await m.database.customStatement(
          'CREATE TABLE maintenance_events ('
          'id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36), '
          'user_id TEXT NULL CHECK (user_id IS NULL OR length(user_id) = 36), '
          'row_version INTEGER NULL, '
          'updated_at TEXT NOT NULL, '
          'deleted_at TEXT NULL, '
          'mutation_id TEXT NOT NULL CHECK (length(mutation_id) = 36), '
          'vehicle_id TEXT NOT NULL CHECK (length(vehicle_id) = 36) '
          '  REFERENCES vehicles (id), '
          'rule_id TEXT NULL CHECK (rule_id IS NULL OR length(rule_id) = 36) '
          '  REFERENCES maintenance_rules (id), '
          'performed_at TEXT NOT NULL, '
          'odometer_m INTEGER NOT NULL CHECK (odometer_m >= 0), '
          'cost_cents INTEGER NOT NULL DEFAULT 0 CHECK (cost_cents >= 0), '
          'currency_code TEXT NOT NULL CHECK (length(currency_code) = 3) '
          "  CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]'), "
          'notes TEXT NULL CHECK (notes IS NULL OR length(notes) <= 500)'
          ')',
        );
        await m.database.customStatement(
          'INSERT INTO maintenance_events ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, rule_id, performed_at, odometer_m, cost_cents, '
          'currency_code, notes'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, rule_id, performed_at, COALESCE(odometer_m, 0), '
          'cost_cents, currency_code, notes '
          'FROM _maintenance_events_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _maintenance_events_backup',
        );
      },
    ),
  ];
}
