import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

void main() {
  group('SettingsRepository', () {
    test('getOrBootstrap() creates a row with v1 defaults on fresh install',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);

      final row = await repo.getOrBootstrap();

      expect(row.preferredDistanceUnit, 'km');
      expect(row.preferredVolumeUnit, 'L');
      expect(row.currencyCode, 'EUR');
      expect(row.timezone, 'UTC');
      expect(row.id.length, 36, reason: 'UUIDv4 is 36 chars');
      expect(row.mutationId, isNotEmpty);
    });

    test('getOrBootstrap() is idempotent', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);

      final first = await repo.getOrBootstrap();
      final second = await repo.getOrBootstrap();
      expect(second.id, first.id,
          reason: 'second call returns the existing row');
    });

    test('update() rewrites only the supplied fields', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);

      await repo.getOrBootstrap();
      final updated = await repo.update(
        currencyCode: 'CZK',
        timezone: 'Europe/Prague',
      );

      expect(updated.currencyCode, 'CZK');
      expect(updated.timezone, 'Europe/Prague');
      expect(updated.preferredDistanceUnit, 'km',
          reason: 'unspecified field unchanged');
      expect(updated.preferredVolumeUnit, 'L');
    });

    test('update() bootstraps if no row exists yet', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);

      final row = await repo.update(timezone: 'America/Los_Angeles');
      expect(row.timezone, 'America/Los_Angeles');
      expect(row.currencyCode, 'EUR', reason: 'default kept on bootstrap path');
    });
  });
}
