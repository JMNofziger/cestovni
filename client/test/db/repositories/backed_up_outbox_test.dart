import 'dart:convert';

import 'package:cestovni/db/repositories/maintenance_events_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

void main() {
  group('VehiclesRepository outbox', () {
    test('create, update, archive, unarchive, and softDelete enqueue',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db);
      const draft = VehicleDraft(
        name: 'Octavia',
        fuelType: VehicleFuelType.diesel,
        make: 'Skoda',
        tankCapacityUL: 50000000,
      );

      final id = await repo.create(draft);
      var rows = await _table(db, 'vehicles');
      expect(rows, hasLength(1));
      expect(rows.single.op, 'insert');
      var payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['name'], 'Octavia');
      expect(payload['fuel_type'], 'diesel');
      expect(payload['tank_capacity_uL'], 50000000);
      expect(payload.containsKey('user_id'), isFalse);
      expect(payload.containsKey('row_version'), isFalse);

      await repo.update(
        id,
        const VehicleDraft(name: 'Octavia RS', fuelType: VehicleFuelType.diesel),
      );
      rows = await _table(db, 'vehicles');
      expect(rows, hasLength(1), reason: 'update coalesces into the pending insert');
      expect(rows.single.op, 'insert');
      payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['name'], 'Octavia RS');

      await (db.delete(db.outbox)).go();
      await repo.archive(id);
      rows = await _table(db, 'vehicles');
      expect(rows.single.op, 'update');
      payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['archived_at'], isNotNull);

      await (db.delete(db.outbox)).go();
      await repo.unarchive(id);
      rows = await _table(db, 'vehicles');
      payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['archived_at'], isNull);
      expect(rows.single.op, 'update');

      await repo.softDelete(id);
      rows = await _table(db, 'vehicles');
      expect(rows, hasLength(1));
      expect(rows.single.op, 'soft_delete');
      expect(rows.single.payloadJson, isNull);
      expect(await repo.findById(id), isNull);
    });

    test('enqueue: false writes the vehicle and skips the outbox', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final id = await VehiclesRepository(db, enqueue: false).create(
        const VehicleDraft(name: 'Local', fuelType: VehicleFuelType.gasoline),
      );
      expect(await db.select(db.vehicles).get(), hasLength(1));
      expect(id, isNotEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('a failed enqueue rolls the vehicle insert back', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = VehiclesRepository(db, outbox: _BoomOutbox(db));
      await expectLater(
        repo.create(
          const VehicleDraft(name: 'Nope', fuelType: VehicleFuelType.gasoline),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await db.select(db.vehicles).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
    });
  });

  group('SettingsRepository outbox', () {
    test('bootstrap does not enqueue; first update is an insert', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      final boot = await repo.getOrBootstrap();
      expect(boot.rowVersion, isNull);
      expect(await db.select(db.outbox).get(), isEmpty);

      final updated = await repo.update(timezone: 'Europe/Prague');
      expect(updated.timezone, 'Europe/Prague');
      final rows = await _table(db, 'settings');
      expect(rows, hasLength(1));
      expect(rows.single.op, 'insert');
      expect(rows.single.rowId, boot.id);
      final payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['timezone'], 'Europe/Prague');
      expect(payload['preferred_distance_unit'], 'km');
      expect(payload.containsKey('user_id'), isFalse);
      expect(payload.containsKey('row_version'), isFalse);

      await repo.update(currencyCode: 'CZK');
      final coalesced = await _table(db, 'settings');
      expect(coalesced, hasLength(1));
      expect(coalesced.single.op, 'insert');
      expect(coalesced.single.mutationId, rows.single.mutationId);
      final next = jsonDecode(coalesced.single.payloadJson!) as Map<String, dynamic>;
      expect(next['currency_code'], 'CZK');
    });

    test('a synced settings row enqueues update', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      final boot = await repo.getOrBootstrap();
      await (db.update(db.appSettings)..where((s) => s.id.equals(boot.id)))
          .write(const AppSettingsCompanion(rowVersion: Value(7)));
      await repo.update(timezone: 'Europe/Prague');
      final rows = await _table(db, 'settings');
      expect(rows.single.op, 'update');
    });

    test('a failed settings enqueue rolls the preference write back', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db, outbox: _BoomOutbox(db));
      await repo.getOrBootstrap();
      await expectLater(
        repo.update(timezone: 'Europe/Prague'),
        throwsA(isA<StateError>()),
      );
      final row = await repo.getOrBootstrap();
      expect(row.timezone, 'UTC');
      expect(await db.select(db.outbox).get(), isEmpty);
    });
  });

  group('Maintenance outbox', () {
    test('event create coalesces, softDelete supersedes', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await VehiclesRepository(db, enqueue: false).create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final repo = MaintenanceEventsRepository(db);
      final id = await repo.create(
        MaintenanceEventDraft(
          vehicleId: vehicleId,
          performedAt: DateTime.utc(2026, 7, 1),
          category: 'oil',
          costCents: 1000,
          currencyCode: 'EUR',
          shop: 'Bosch',
        ),
      );
      var rows = await _table(db, 'maintenance_events');
      expect(rows.single.op, 'insert');
      final payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['category'], 'oil');
      expect(payload['cost_cents'], 1000);
      expect(payload.containsKey('user_id'), isFalse);

      await repo.softDelete(id);
      rows = await _table(db, 'maintenance_events');
      expect(rows, hasLength(1));
      expect(rows.single.op, 'soft_delete');
      expect(rows.single.payloadJson, isNull);
    });

    test('new rule is insert; a later edit after flush is update', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await VehiclesRepository(db, enqueue: false).create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final repo = MaintenanceEventsRepository(db);
      final id = await repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: 'oil',
          cadenceMeters: 10000000,
        ),
      );
      var rows = await _table(db, 'maintenance_rules');
      expect(rows.single.op, 'insert');
      var payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['cadence_m'], 10000000);
      expect(payload['name'], 'oil');

      await repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: 'oil',
          cadenceDays: 180,
        ),
      );
      rows = await _table(db, 'maintenance_rules');
      expect(rows, hasLength(1));
      expect(rows.single.op, 'insert');
      payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['cadence_days'], 180);

      await (db.delete(db.outbox)).go();
      await repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: 'oil',
          cadenceMeters: 15000000,
          cadenceDays: 180,
        ),
      );
      rows = await _table(db, 'maintenance_rules');
      expect(rows.single.op, 'update');
      expect(rows.single.rowId, id);
      payload = jsonDecode(rows.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['cadence_m'], 15000000);
    });

    test('a failed event enqueue rolls the event back', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await VehiclesRepository(db, enqueue: false).create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final repo = MaintenanceEventsRepository(db, outbox: _BoomOutbox(db));
      await expectLater(
        repo.create(
          MaintenanceEventDraft(
            vehicleId: vehicleId,
            performedAt: DateTime.utc(2026, 7, 2),
            category: 'tires',
            costCents: 0,
            currencyCode: 'EUR',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await db.select(db.maintenanceEvents).get(), isEmpty);
    });
  });
}

Future<List<OutboxRow>> _table(dynamic db, String table) {
  return (db.select(db.outbox)..where((o) => o.table_.equals(table))).get();
}

class _BoomOutbox extends OutboxRepository {
  _BoomOutbox(super.db);

  @override
  Future<int> enqueueInsert({
    required String table,
    required String rowId,
    required Map<String, dynamic> payload,
  }) {
    throw StateError('enqueue failed');
  }

  @override
  Future<int> enqueueUpdate({
    required String table,
    required String rowId,
    required Map<String, dynamic> payload,
  }) {
    throw StateError('enqueue failed');
  }
}
