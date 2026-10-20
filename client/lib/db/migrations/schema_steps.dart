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
    MigrationStep(
      from: 2,
      to: 3,
      name: '0003_settings_default_vehicle_id',

      // Closes CES-57 — see docs/specs/data-model.md §settings and
      // client/lib/db/tables/settings.dart. A plain nullable column
      // add: no NOT NULL/CHECK relaxation is involved (contrast 0002),
      // so a simple ALTER suffices and no table rebuild is needed.
      up: (m) async {
        await m.database.customStatement(
          'ALTER TABLE settings ADD COLUMN default_vehicle_id TEXT NULL',
        );
      },
      // Rollback hook for CES-47.
      down: (m) async {
        await m.database.customStatement(
          'ALTER TABLE settings DROP COLUMN default_vehicle_id',
        );
      },
    ),
    MigrationStep(
      from: 3,
      to: 4,
      name: '0004_rename_cadence_km_to_cadence_m',
      // Closes CES-71 — rename maintenance_rules.cadence_km → cadence_m.
      // The column stores canonical meters; the old name was misleading.
      // SQLite does not support ALTER COLUMN RENAME, so we rebuild the
      // table. The new table uses Drift's generated CREATE TABLE (via
      // `m.createTable`) so the schema is byte-identical to a fresh
      // `onCreate` install.
      up: (m) async {
        final maintenanceRulesTable = allTables.firstWhere(
          (t) => t.actualTableName == 'maintenance_rules',
        );
        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _maintenance_rules_backup AS '
          'SELECT * FROM maintenance_rules',
        );
        await m.deleteTable('maintenance_rules');
        await m.createTable(maintenanceRulesTable);
        await m.database.customStatement(
          'INSERT INTO maintenance_rules ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, name, cadence_m, cadence_days, enabled, notes'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, name, cadence_km, cadence_days, enabled, notes '
          'FROM _maintenance_rules_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _maintenance_rules_backup',
        );
      },
      // Rollback: rebuild back to cadence_km.
      down: (m) async {
        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _maintenance_rules_backup AS '
          'SELECT * FROM maintenance_rules',
        );
        await m.deleteTable('maintenance_rules');
        await m.database.customStatement(
          'CREATE TABLE maintenance_rules ('
          'id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36), '
          'user_id TEXT NULL CHECK (user_id IS NULL OR length(user_id) = 36), '
          'row_version INTEGER NULL, '
          'updated_at TEXT NOT NULL, '
          'deleted_at TEXT NULL, '
          'mutation_id TEXT NOT NULL CHECK (length(mutation_id) = 36), '
          'vehicle_id TEXT NOT NULL CHECK (length(vehicle_id) = 36) '
          '  REFERENCES vehicles (id), '
          'name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80), '
          'cadence_km INTEGER NULL CHECK (cadence_km IS NULL OR cadence_km > 0), '
          'cadence_days INTEGER NULL CHECK (cadence_days IS NULL OR cadence_days > 0), '
          'enabled INTEGER NOT NULL DEFAULT 1, '
          'notes TEXT NULL CHECK (notes IS NULL OR length(notes) <= 500), '
          'CHECK (cadence_km IS NOT NULL OR cadence_days IS NOT NULL)'
          ')',
        );
        await m.database.customStatement(
          'INSERT INTO maintenance_rules ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, name, cadence_km, cadence_days, enabled, notes'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'vehicle_id, name, cadence_m, cadence_days, enabled, notes '
          'FROM _maintenance_rules_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _maintenance_rules_backup',
        );
      },
    ),
    MigrationStep(
      from: 4,
      to: 5,
      name: '0005_settings_check_id_eq_user_id',
      // Closes CES-49 — enforce `id = user_id` at the DB level on the
      // `settings` table. The spec says "enforced by trigger (or
      // app-level invariant)"; this upgrades the client from app-level
      // to a CHECK constraint. SQLite requires a table rebuild to add
      // a table-level CHECK.
      up: (m) async {
        final settingsTable = allTables.firstWhere(
          (t) => t.actualTableName == 'settings',
        );
        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _settings_backup AS '
          'SELECT * FROM settings',
        );
        await m.deleteTable('settings');
        await m.createTable(settingsTable);
        await m.database.customStatement(
          'INSERT INTO settings ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'preferred_distance_unit, preferred_volume_unit, currency_code, '
          'timezone, default_vehicle_id'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'preferred_distance_unit, preferred_volume_unit, currency_code, '
          'timezone, default_vehicle_id '
          'FROM _settings_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _settings_backup',
        );
      },
      // Rollback: rebuild without the CHECK.
      down: (m) async {
        await m.database.customStatement(
          'CREATE TEMPORARY TABLE _settings_backup AS '
          'SELECT * FROM settings',
        );
        await m.deleteTable('settings');
        await m.database.customStatement(
          'CREATE TABLE settings ('
          'id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36), '
          'user_id TEXT NULL CHECK (user_id IS NULL OR length(user_id) = 36), '
          'row_version INTEGER NULL, '
          'updated_at TEXT NOT NULL, '
          'deleted_at TEXT NULL, '
          'mutation_id TEXT NOT NULL CHECK (length(mutation_id) = 36), '
          "preferred_distance_unit TEXT NOT NULL CHECK (preferred_distance_unit IN ('km','mi')), "
          "preferred_volume_unit TEXT NOT NULL CHECK (preferred_volume_unit IN ('L','gal')), "
          "currency_code TEXT NOT NULL CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]'), "
          'timezone TEXT NOT NULL CHECK (length(timezone) BETWEEN 1 AND 64), '
          'default_vehicle_id TEXT NULL'
          ')',
        );
        await m.database.customStatement(
          'INSERT INTO settings ('
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'preferred_distance_unit, preferred_volume_unit, currency_code, '
          'timezone, default_vehicle_id'
          ') SELECT '
          'id, user_id, row_version, updated_at, deleted_at, mutation_id, '
          'preferred_distance_unit, preferred_volume_unit, currency_code, '
          'timezone, default_vehicle_id '
          'FROM _settings_backup',
        );
        await m.database.customStatement(
          'DROP TABLE _settings_backup',
        );
      },
    ),
  ];
}
