import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

void main() {
  group('VehiclesRepository', () {
    test('create() inserts a live vehicle and returns its id', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);

      final id = await repo.create(
        const VehicleDraft(
          name: 'Octavia',
          fuelType: VehicleFuelType.gasoline,
        ),
      );

      final found = await repo.findById(id);
      expect(found, isNotNull);
      expect(found!.name, 'Octavia');
      expect(found.fuelType, 'gasoline');
      expect(found.deletedAt, isNull);
      expect(found.archivedAt, isNull);
      expect(found.mutationId, isNotEmpty,
          reason: 'mutation_id is required for outbox replay (M3)');
    });

    test('watchLive() emits ordered live vehicles only', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);

      await repo.create(
        const VehicleDraft(name: 'B', fuelType: VehicleFuelType.diesel),
      );
      final aId = await repo.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final cId = await repo.create(
        const VehicleDraft(name: 'C', fuelType: VehicleFuelType.evKwh),
      );

      await repo.softDelete(cId);

      final live = await repo.liveOnce();
      expect(live.map((v) => v.name).toList(), ['A', 'B'],
          reason: 'name ASC, soft-deleted dropped');

      final updated = await repo.update(
        aId,
        const VehicleDraft(
          name: 'Aardvark',
          fuelType: VehicleFuelType.gasoline,
          year: 2020,
        ),
      );
      expect(updated, isTrue);

      final reread = await repo.findById(aId);
      expect(reread!.name, 'Aardvark');
      expect(reread.year, 2020);
    });

    test('softDelete() is idempotent and excludes from live queries',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);

      final id = await repo.create(
        const VehicleDraft(name: 'X', fuelType: VehicleFuelType.gasoline),
      );

      expect(await repo.softDelete(id), isTrue);
      expect(await repo.softDelete(id), isFalse,
          reason: 'second call is a no-op (deletedAt already set)');
      expect(await repo.findById(id), isNull);

      final all = await repo.watchAll().first;
      expect(all.length, 1, reason: 'soft-deleted row still present in raw view');
    });

    test('archive()/unarchive() toggle archived_at without losing live status',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);

      final id = await repo.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      expect(await repo.archive(id), isTrue);
      expect((await repo.liveOnce()).where((v) => v.id == id), isEmpty,
          reason: 'archived rows are not live for the selector');

      expect(await repo.unarchive(id), isTrue);
      expect(
        (await repo.liveOnce()).where((v) => v.id == id).length,
        1,
        reason: 'unarchive restores the row to live',
      );
    });

    test('update() refuses to touch a soft-deleted row', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);

      final id = await repo.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      await repo.softDelete(id);

      final wrote = await repo.update(
        id,
        const VehicleDraft(name: 'Renamed', fuelType: VehicleFuelType.diesel),
      );
      expect(wrote, isFalse,
          reason: 'soft-deleted vehicles are read-only from the UI in v1');
    });

    test('VehicleFuelType.fromWire round-trips every wire value', () {
      for (final t in VehicleFuelType.values) {
        expect(VehicleFuelType.fromWire(t.wire), t);
      }
      expect(
        () => VehicleFuelType.fromWire('rocket_fuel'),
        throwsArgumentError,
      );
    });
  });
}
