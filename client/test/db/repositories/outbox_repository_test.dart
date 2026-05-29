import 'dart:convert';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../_harness.dart';

/// Tests for the CES-44 minimal outbox slice (gate slice). Covers:
///   - `create` enqueues exactly one `op=insert` row with snake_case payload
///   - `amend` coalesces into the pending row (no duplicate updates)
///   - `softDelete` drops pending inserts/updates and queues a single
///     `op=soft_delete` row with null payload
///   - `mutation_id` is generated at enqueue (separate from the row's
///     own `mutation_id`) and is a UUIDv4-shaped string
///   - `pendingBatch` returns oldest-first up to the protocol cap
void main() {
  group('OutboxRepository — fill_ups lifecycle (CES-44 gate slice)', () {
    test('FillUpsRepository.create enqueues exactly one insert row',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final outbox = OutboxRepository(db);
      final repo = FillUpsRepository(db, outbox: outbox);

      final vehicleId = await vehicles.create(
        const VehicleDraft(
          name: 'Octavia',
          fuelType: VehicleFuelType.gasoline,
        ),
      );

      final id = await repo.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 5, 1, 9, 30),
          odometerM: 120_000_000,
          volumeUL: 42_000_000,
          totalPriceCents: 5_912,
          currencyCode: 'EUR',
          isFull: true,
          notes: 'shell highway',
        ),
      );

      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1),
          reason: 'create must enqueue exactly one outbox row');

      final entry = rows.single;
      expect(entry.table_, 'fill_ups');
      expect(entry.op, 'insert');
      expect(entry.rowId, id);
      expect(entry.attempts, 0);
      expect(entry.lastError, isNull);
      expect(entry.mutationId, hasLength(36),
          reason: 'mutation_id is UUIDv4 generated at enqueue');

      final payload =
          jsonDecode(entry.payloadJson!) as Map<String, dynamic>;
      expect(payload['id'], id);
      expect(payload['vehicle_id'], vehicleId);
      expect(payload['odometer_m'], 120_000_000);
      expect(payload['volume_uL'], 42_000_000);
      expect(payload['total_price_cents'], 5_912);
      expect(payload['currency_code'], 'EUR');
      expect(payload['is_full'], isTrue);
      expect(payload['missed_before'], isFalse);
      expect(payload['odometer_reset'], isFalse);
      expect(payload['notes'], 'shell highway');
      expect(payload['deleted_at'], isNull);
      expect(payload['mutation_id'], isA<String>(),
          reason:
              'row-level mutation_id is sent so server can dedupe future amends');
      expect(payload['mutation_id'], isNot(entry.mutationId),
          reason: 'outbox enqueue id is independent of row mutation_id');
    });

    test('amend coalesces pending insert + update into one row '
        '(latest payload wins)', () async {
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
      await repo.amend(
        id,
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 1_000_000,
          volumeUL: 32_000_000,
          totalPriceCents: 5_200,
          currencyCode: 'EUR',
          isFull: true,
          notes: 'pump misread x2',
        ),
      );

      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1),
          reason: 'sync-protocol.md §Fill-up lifecycle: multiple pending '
              'updates coalesce into a single outbox entry before send');
      final entry = rows.single;
      expect(entry.op, 'insert',
          reason: 'never-synced row keeps its original insert op; only the '
              'payload is rewritten so the server sees the final snapshot');
      final payload =
          jsonDecode(entry.payloadJson!) as Map<String, dynamic>;
      expect(payload['volume_uL'], 32_000_000);
      expect(payload['total_price_cents'], 5_200);
      expect(payload['notes'], 'pump misread x2');
    });

    test('softDelete drops pending insert/update and enqueues one '
        'soft_delete row', () async {
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
          filledAt: DateTime.utc(2026, 5, 2),
          odometerM: 1_000_000,
          volumeUL: 30_000_000,
          totalPriceCents: 5_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      await repo.softDelete(id);

      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1));
      final entry = rows.single;
      expect(entry.op, 'soft_delete');
      expect(entry.rowId, id);
      expect(entry.payloadJson, isNull,
          reason: 'sync-protocol.md: soft_delete carries no payload');
    });

    test('softDelete after a synced insert leaves the soft_delete on its '
        'own (no coalescing across ops)', () async {
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
          filledAt: DateTime.utc(2026, 5, 3),
          odometerM: 1_000_000,
          volumeUL: 30_000_000,
          totalPriceCents: 5_000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      // Simulate a successful flush — drain the outbox.
      await (db.delete(db.outbox)).go();

      await repo.softDelete(id);
      final rows = await db.select(db.outbox).get();
      expect(rows.map((r) => r.op), ['soft_delete']);
    });

    test('pendingBatch is oldest-first and capped at 100', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db);

      for (var i = 0; i < 105; i++) {
        await db.into(db.outbox).insert(
              OutboxCompanion.insert(
                mutationId: '00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}',
                table_: 'fill_ups',
                op: 'insert',
                rowId: '00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}',
                payloadJson: const Value('{}'),
                enqueuedAt: '2026-05-01T00:00:00Z',
              ),
            );
      }

      final batch = await outbox.pendingBatch();
      expect(batch, hasLength(100),
          reason: 'sync-protocol.md §POST /mutations: 100/batch cap');
      expect(batch.first.id, lessThan(batch.last.id),
          reason: 'oldest-first ordering for FIFO drain');
    });

    test('recordRetry bumps attempts and stores last_error', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db);

      final id = await db.into(db.outbox).insert(
            OutboxCompanion.insert(
              mutationId: '11111111-1111-1111-1111-111111111111',
              table_: 'fill_ups',
              op: 'insert',
              rowId: '22222222-2222-2222-2222-222222222222',
              payloadJson: const Value('{}'),
              enqueuedAt: '2026-05-01T00:00:00Z',
            ),
          );

      await outbox.recordRetry(id, lastError: 'http 503');
      await outbox.recordRetry(id, lastError: 'http 500');

      final row =
          await (db.select(db.outbox)..where((o) => o.id.equals(id))).getSingle();
      expect(row.attempts, 2);
      expect(row.lastError, 'http 500');
    });
  });
}
