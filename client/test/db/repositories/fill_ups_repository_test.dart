import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

// Outbox shape + coalescing is covered exhaustively in
// `outbox_repository_test.dart`; the assertions below are the
// FillUpsRepository-side contract that each write enqueues exactly
// one outbox transition (CES-44 gate slice).

void main() {
  group('FillUpsRepository', () {
    test('create() persists every column and respects FK to vehicles',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = FillUpsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(
          name: 'Octavia',
          fuelType: VehicleFuelType.gasoline,
        ),
      );

      final id = await repo.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 4, 1, 12),
          odometerM: 100_000_000,
          volumeUL: 40_000_000,
          totalPriceCents: 6_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      final row = await repo.findById(id);
      expect(row, isNotNull);
      expect(row!.vehicleId, vehicleId);
      expect(row.odometerM, 100_000_000);
      expect(row.volumeUL, 40_000_000);
      expect(row.totalPriceCents, 6_000);
      expect(row.currencyCode, 'EUR');
      expect(row.isFull, isTrue);
      expect(row.missedBefore, isFalse);
      expect(row.odometerReset, isFalse);
      expect(row.deletedAt, isNull);
      expect(row.mutationId, isNotEmpty);
    });

    test('listForVehicle() is asc and excludes other vehicles + soft-deleted',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = FillUpsRepository(db);

      final v1 = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final v2 = await vehicles.create(
        const VehicleDraft(name: 'B', fuelType: VehicleFuelType.gasoline),
      );

      final firstId = await repo.create(
        FillUpDraft(
          vehicleId: v1,
          filledAt: DateTime.utc(2026, 1, 1),
          odometerM: 1_000_000,
          volumeUL: 30_000_000,
          totalPriceCents: 5_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
      await repo.create(
        FillUpDraft(
          vehicleId: v1,
          filledAt: DateTime.utc(2026, 2, 1),
          odometerM: 1_500_000,
          volumeUL: 35_000_000,
          totalPriceCents: 5_500,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
      await repo.create(
        FillUpDraft(
          vehicleId: v2,
          filledAt: DateTime.utc(2026, 1, 15),
          odometerM: 2_000_000,
          volumeUL: 40_000_000,
          totalPriceCents: 6_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      final v1List = await repo.listForVehicle(v1);
      expect(v1List.length, 2);
      expect(v1List.first.filledAt.startsWith('2026-01-01'), isTrue,
          reason: 'asc order for math kick-offs');

      await repo.softDelete(firstId);
      final v1ListAfter = await repo.listForVehicle(v1);
      expect(v1ListAfter.length, 1);
      expect(v1ListAfter.first.filledAt.startsWith('2026-02-01'), isTrue);
    });

    test('amend() rewrites editable fields on a live row only', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = FillUpsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      final id = await repo.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 1, 1),
          odometerM: 1_000_000,
          volumeUL: 30_000_000,
          totalPriceCents: 5_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      final wrote = await repo.amend(
        id,
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 1, 1),
          odometerM: 1_000_000,
          volumeUL: 31_000_000,
          totalPriceCents: 5_100,
          currencyCode: 'EUR',
          isFull: true,
          notes: 'corrected pump misread',
        ),
      );
      expect(wrote, isTrue);

      final row = await repo.findById(id);
      expect(row!.volumeUL, 31_000_000);
      expect(row.totalPriceCents, 5_100);
      expect(row.notes, 'corrected pump misread');

      await repo.softDelete(id);
      final wroteAfterDelete = await repo.amend(
        id,
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 1, 1),
          odometerM: 1_000_000,
          volumeUL: 99,
          totalPriceCents: 0,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
      expect(wroteAfterDelete, isFalse,
          reason: 'soft-deleted rows are immutable from the UI');
    });

    test('create / amend / softDelete each enqueue exactly one outbox row '
        '(CES-44 gate slice)', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = FillUpsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      final id = await repo.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 1_000_000,
          volumeUL: 30_000_000,
          totalPriceCents: 5_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
      var rows = await db.select(db.outbox).get();
      expect(rows.map((r) => r.op), ['insert'],
          reason: 'exactly one insert row after create');

      // Drain (simulate a successful flush) so the amend/softDelete
      // assertions read against an empty outbox.
      await db.delete(db.outbox).go();

      await repo.amend(
        id,
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 1_000_000,
          volumeUL: 31_000_000,
          totalPriceCents: 5_100,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
      rows = await db.select(db.outbox).get();
      expect(rows.map((r) => r.op), ['update'],
          reason: 'amend after a synced row enqueues a fresh update');

      await db.delete(db.outbox).go();
      await repo.softDelete(id);
      rows = await db.select(db.outbox).get();
      expect(rows.map((r) => r.op), ['soft_delete']);
      expect(rows.single.payloadJson, isNull);
    });
  });
}
