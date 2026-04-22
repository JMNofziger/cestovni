import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

void main() {
  group('migration', () {
    test('fresh onCreate lands on current schemaVersion with all 8 tables', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      // Touch the DB so Drift runs `onCreate` (= upgrade from 0 to
      // schemaVersion via the MigrationRunner).
      await db.customSelect('SELECT 1').get();

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
            "ORDER BY name",
          )
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();

      expect(names, {
        'drafts',
        'fill_ups',
        'maintenance_events',
        'maintenance_rules',
        'outbox',
        'photo_refs',
        'settings',
        'vehicles',
      });
      expect(db.schemaVersion, 2);
    });

    test(
      'onCreate maintenance_events has v2 columns (category, shop) and '
      'nullable odometer_m',
      () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        await db.customSelect('SELECT 1').get();

        final cols = await db
            .customSelect('PRAGMA table_info(maintenance_events)')
            .get();
        final byName = {
          for (final r in cols) r.read<String>('name'): r,
        };

        expect(byName.containsKey('category'), isTrue);
        expect(byName.containsKey('shop'), isTrue);

        expect(byName['category']!.read<int>('notnull'), 1);
        expect(byName['category']!.read<String>('dflt_value'), "'other'");

        expect(byName['shop']!.read<int>('notnull'), 0);
        expect(byName['odometer_m']!.read<int>('notnull'), 0,
            reason: 'odometer_m is optional after CES-53');
      },
    );

    test('current → current upgrade is a no-op', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // onCreate

      // Second open — Drift calls neither onCreate nor onUpgrade since
      // from == to. We can't easily run that over a fresh executor;
      // proxy via the runner directly with an empty migrator.
      final steps = db.migrationRunner.steps;
      final noop = steps.where(
        (s) => s.from >= db.schemaVersion && s.to <= db.schemaVersion,
      );
      expect(noop, isEmpty, reason: 'no step fires when from == to');
    });

    test(
      '0001_init.down drops every table (rollback hook for CES-47)',
      () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        await db.customSelect('SELECT 1').get(); // ensure schema exists

        final step = db.migrationRunner.steps.firstWhere(
          (s) => s.name == '0001_init',
        );

        // Use the real Migrator surface to exercise the down() hook.
        await db.transaction(() async {
          final migrator = Migrator(db);
          await step.down(migrator);
        });

        final tables = await db
            .customSelect(
              "SELECT count(*) AS c FROM sqlite_master WHERE type='table' "
              "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
            )
            .getSingle();
        expect(tables.read<int>('c'), 0);
      },
    );

    test('0002 round-trips v1 maintenance_events data and adds v2 columns', () async {
      // Simulate a user upgrading from a v1 install: seed a fresh v1
      // schema, stuff a realistic row in, then run the 0002 step and
      // assert the row still lives, category defaulted to 'other',
      // shop is NULL, and odometer_m is now nullable.
      final db = openInMemoryDb();
      addTearDown(db.close);

      // Build v1 maintenance_events by hand (Drift currently emits v2
      // on onCreate, so we can't lean on it here).
      await db.customSelect('SELECT 1').get();
      final vehicleId = '00000000-0000-4000-8000-000000000001';
      final userId = '00000000-0000-4000-8000-0000000000aa';
      final mutationId = '00000000-0000-4000-8000-0000000000b1';
      final eventId = '00000000-0000-4000-8000-000000000301';
      await db.customStatement(
        "INSERT INTO vehicles "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " name, fuel_type) "
        "VALUES (?, ?, 1, ?, ?, 'Seed', 'gasoline')",
        [vehicleId, userId, '2026-04-22T12:00:00Z', mutationId],
      );

      // Drop the v2 maintenance_events and recreate a v1 shape so we
      // can exercise the upgrade path against realistic inputs.
      await db.customStatement('DROP TABLE maintenance_events');
      await db.customStatement(
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
      await db.customStatement(
        "INSERT INTO maintenance_events "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, performed_at, odometer_m, cost_cents, currency_code, notes) "
        "VALUES (?, ?, 1, ?, ?, ?, ?, 123000, 4500, 'EUR', 'v1 row')",
        [eventId, userId, '2026-04-22T12:00:00Z', mutationId, vehicleId, '2026-04-22T12:00:00Z'],
      );

      final step = db.migrationRunner.steps.firstWhere(
        (s) => s.name == '0002_add_maintenance_events_category_shop',
      );
      await db.transaction(() async {
        final migrator = Migrator(db);
        await step.up(migrator);
      });

      final rows = await db
          .customSelect(
            "SELECT category, shop, odometer_m, cost_cents, notes "
            "FROM maintenance_events WHERE id = ?",
            variables: [Variable.withString(eventId)],
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('category'), 'other');
      expect(rows.single.readNullable<String>('shop'), isNull);
      expect(rows.single.read<int>('odometer_m'), 123000);
      expect(rows.single.read<int>('cost_cents'), 4500);
      expect(rows.single.read<String>('notes'), 'v1 row');

      // Nullable odometer_m must now actually accept NULL.
      final eventId2 = '00000000-0000-4000-8000-000000000302';
      final mutationId2 = '00000000-0000-4000-8000-0000000000b2';
      await db.customStatement(
        "INSERT INTO maintenance_events "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, performed_at, odometer_m, cost_cents, currency_code, "
        " category, shop) "
        "VALUES (?, ?, 2, ?, ?, ?, ?, NULL, 0, 'EUR', 'oil', 'Mr. Lube')",
        [eventId2, userId, '2026-04-22T13:00:00Z', mutationId2, vehicleId, '2026-04-22T13:00:00Z'],
      );
    });

    test('foreign keys are enforced (PRAGMA on)', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final row = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(row.data.values.first, 1);
    });
  });
}
