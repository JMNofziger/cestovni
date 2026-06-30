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
      expect(row.defaultVehicleId, isNull,
          reason: 'CES-57: no default vehicle until explicitly set');
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

    group('defaultVehicleId (CES-57)', () {
      test('omitting the param leaves defaultVehicleId unchanged', () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        final repo = SettingsRepository(db);
        const vehicleId = '00000000-0000-4000-8000-000000000001';

        await repo.update(defaultVehicleId: vehicleId);
        final row = await repo.update(currencyCode: 'CZK');

        expect(row.defaultVehicleId, vehicleId,
            reason: 'omitted arg must not clobber a previously set value');
        expect(row.currencyCode, 'CZK');
      });

      test('passing a vehicle id sets defaultVehicleId', () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        final repo = SettingsRepository(db);
        const vehicleId = '00000000-0000-4000-8000-000000000002';

        final row = await repo.update(defaultVehicleId: vehicleId);

        expect(row.defaultVehicleId, vehicleId);
      });

      test('passing explicit null clears a previously set defaultVehicleId',
          () async {
        final db = openInMemoryDb();
        addTearDown(db.close);
        final repo = SettingsRepository(db);
        const vehicleId = '00000000-0000-4000-8000-000000000003';

        await repo.update(defaultVehicleId: vehicleId);
        final cleared = await repo.update(defaultVehicleId: null);

        expect(cleared.defaultVehicleId, isNull,
            reason: 'explicit null must distinguish "clear" from "omit"');
      });
    });
  });
}
