import 'package:cestovni/db/repositories/maintenance_events_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

void main() {
  group('MaintenanceEventsRepository', () {
    test('create() persists columns including nullable odometer and blank cost',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = MaintenanceEventsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(
          name: 'Octavia',
          fuelType: VehicleFuelType.gasoline,
        ),
      );

      final id = await repo.create(
        MaintenanceEventDraft(
          vehicleId: vehicleId,
          performedAt: DateTime.utc(2026, 4, 18, 12),
          category: 'oil',
          costCents: 0,
          currencyCode: 'EUR',
          shop: '  Bosch  ',
          notes: 'filter too',
        ),
      );

      final row = await repo.findById(id);
      expect(row, isNotNull);
      expect(row!.vehicleId, vehicleId);
      expect(row.category, 'oil');
      expect(row.odometerM, isNull);
      expect(row.costCents, 0);
      expect(row.currencyCode, 'EUR');
      expect(row.shop, 'Bosch');
      expect(row.notes, 'filter too');
      expect(row.deletedAt, isNull);
      expect(row.performedAt.startsWith('2026-04-18T12:00:00'), isTrue);
    });

    test('listForVehicle excludes other vehicles and soft-deleted', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = MaintenanceEventsRepository(db);

      final v1 = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final v2 = await vehicles.create(
        const VehicleDraft(name: 'B', fuelType: VehicleFuelType.gasoline),
      );

      final first = await repo.create(
        MaintenanceEventDraft(
          vehicleId: v1,
          performedAt: DateTime.utc(2026, 1, 1, 12),
          category: 'tires',
          costCents: 1000,
          currencyCode: 'EUR',
        ),
      );
      await repo.create(
        MaintenanceEventDraft(
          vehicleId: v1,
          performedAt: DateTime.utc(2026, 2, 1, 12),
          category: 'brakes',
          costCents: 2000,
          currencyCode: 'EUR',
        ),
      );
      await repo.create(
        MaintenanceEventDraft(
          vehicleId: v2,
          performedAt: DateTime.utc(2026, 1, 15, 12),
          category: 'oil',
          costCents: 500,
          currencyCode: 'EUR',
        ),
      );

      final listed = await repo.listForVehicle(v1);
      expect(listed.length, 2);
      expect(listed.first.performedAt.startsWith('2026-02-01'), isTrue);

      await repo.softDelete(first);
      final after = await repo.listForVehicle(v1);
      expect(after.length, 1);
      expect(after.first.category, 'brakes');
      expect(await repo.findById(first), isNull);
    });

    test('upsertReminderRule create then update by vehicle+name', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = MaintenanceEventsRepository(db);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      final id1 = await repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: 'oil',
          cadenceKmMeters: 10_000_000,
          cadenceDays: 180,
        ),
      );
      final id2 = await repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: 'oil',
          cadenceKmMeters: 15_000_000,
        ),
      );
      expect(id2, id1);

      final rule = await repo.findRuleByVehicleAndName(vehicleId, 'oil');
      expect(rule, isNotNull);
      expect(rule!.cadenceKm, 15_000_000);
      expect(rule.cadenceDays, isNull);
      expect(rule.enabled, isTrue);
    });

    test('create rejects unknown category', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final repo = MaintenanceEventsRepository(db);
      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );

      expect(
        () => repo.create(
          MaintenanceEventDraft(
            vehicleId: vehicleId,
            performedAt: DateTime.utc(2026, 1, 1, 12),
            category: 'spark-plugs',
            costCents: 0,
            currencyCode: 'EUR',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
