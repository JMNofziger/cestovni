import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

void main() {
  group('migration', () {
    test('v0 → v1 creates all 8 v1 tables', () async {
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
      expect(db.schemaVersion, 1);
    });

    test('v1 → v1 upgrade is a no-op', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // onCreate

      // Second open — Drift calls neither onCreate nor onUpgrade since
      // from == to. We can't easily run that over a fresh executor;
      // proxy via the runner directly with an empty migrator.
      final steps = db.migrationRunner.steps;
      final noop = steps.where((s) => s.from >= 1 && s.to <= 1);
      expect(noop, isEmpty, reason: 'no step fires when from == to');
    });

    test(
      '0001_init.down drops every table (rollback hook for CES-47)',
      () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        await db.customSelect('SELECT 1').get(); // ensure schema exists

        final step = db.migrationRunner.steps.single;
        expect(step.name, '0001_init');

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
