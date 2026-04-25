import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

void main() {
  group('DraftsRepository', () {
    test('save() upserts a single open draft per vehicle', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = DraftsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      final firstId = await repo.save(
        DraftSnapshot(
          vehicleId: vehicleId,
          odometerM: 1_000_000,
          isFull: true,
        ),
      );

      final secondId = await repo.save(
        DraftSnapshot(
          vehicleId: vehicleId,
          odometerM: 1_050_000,
          volumeUL: 40_000_000,
          isFull: true,
          missedBefore: false,
        ),
      );
      expect(secondId, firstId,
          reason: 'a vehicle has at most one open draft in v1');

      final row = await repo.openDraftForVehicle(vehicleId);
      expect(row, isNotNull);
      expect(row!.id, firstId);
      expect(row.odometerM, 1_050_000,
          reason: 'second save overwrote the first');
      expect(row.volumeUL, 40_000_000);
      expect(row.isFull, 1, reason: 'true bool stored as INTEGER 1');
      expect(row.missedBefore, 0);
      expect(row.completedAt, isNull);
    });

    test('markCompleted() flips the row out of the open-draft query',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = DraftsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      final id = await repo.save(DraftSnapshot(vehicleId: vehicleId));
      expect(await repo.openDraftForVehicle(vehicleId), isNotNull);

      expect(await repo.markCompleted(id), isTrue);
      expect(
        await repo.openDraftForVehicle(vehicleId),
        isNull,
        reason: 'completed drafts no longer surface as open',
      );

      // markCompleted is idempotent at the repo layer: a second call
      // still updates the timestamp but doesn't blow up.
      expect(await repo.markCompleted(id), isTrue);
    });

    test('discard() removes the row entirely', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = DraftsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final id = await repo.save(DraftSnapshot(vehicleId: vehicleId));

      expect(await repo.discard(id), isTrue);
      expect(await repo.discard(id), isFalse,
          reason: 'second discard finds nothing to remove');
      expect(await repo.openDraftForVehicle(vehicleId), isNull);
    });

    test('drafts for different vehicles are isolated', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = DraftsRepository(db);

      final v1 = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final v2 = await vehicles.create(
        const VehicleDraft(name: 'B', fuelType: VehicleFuelType.diesel),
      );

      final id1 =
          await repo.save(DraftSnapshot(vehicleId: v1, odometerM: 1));
      final id2 =
          await repo.save(DraftSnapshot(vehicleId: v2, odometerM: 2));

      expect(id1, isNot(id2));
      expect((await repo.openDraftForVehicle(v1))!.odometerM, 1);
      expect((await repo.openDraftForVehicle(v2))!.odometerM, 2);
    });
  });
}
