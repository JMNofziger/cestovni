import 'dart:convert';

import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/sync/outbox_flush_worker.dart';
import 'package:cestovni/sync/sync_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../db/_harness.dart';

/// Worker-level tests for the M3 outbox flush (CES-44 gate slice).
///
/// We use `http`'s `MockClient` to assert request shape (path,
/// payload, headers, batch size) and to script success / failure
/// responses without spinning up the dev sync stub.
void main() {
  group('OutboxFlushWorker (CES-44 gate slice)', () {
    test('drains an applied insert: deletes outbox row, sends bearer + '
        'snake_case payload to /api/v1/mutations', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final outbox = OutboxRepository(db);
      final repo = FillUpsRepository(db, outbox: outbox);

      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      final fillUpId = await repo.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 5, 29, 10),
          odometerM: 120_000_000,
          volumeUL: 42_000_000,
          totalPriceCents: 5_912,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );

      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;
      final mock = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/v1/mutations');
        capturedHeaders = req.headers;
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        final mutationId = (capturedBody['mutations'] as List).first
            ['mutation_id'] as String;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'mutation_id': mutationId,
                'row_id': fillUpId,
                'row_version': 1,
                'server_updated_at': '2026-05-29T10:00:00Z',
                'status': 'applied',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SyncClient(
        baseUrl: 'http://127.0.0.1:8787',
        bearerToken: 'dev-cestovni-token',
        httpClient: mock,
      );
      addTearDown(client.close);
      final worker = OutboxFlushWorker(outbox: outbox, client: client);

      final report = await worker.flushOnce();

      expect(report.sent, 1);
      expect(report.accepted, 1);
      expect(report.duplicates, 0);
      expect(report.rejected, 0);
      expect(report.retriable, 0);

      expect(capturedHeaders['authorization'], 'Bearer dev-cestovni-token');
      expect(capturedHeaders['content-type'],
          contains('application/json'));

      final mutations = capturedBody['mutations'] as List;
      expect(mutations, hasLength(1));
      final m = mutations.first as Map<String, dynamic>;
      expect(m['table'], 'fill_ups');
      expect(m['op'], 'insert');
      expect(m['row_id'], fillUpId);
      final payload = m['payload'] as Map<String, dynamic>;
      expect(payload['odometer_m'], 120_000_000);
      expect(payload['volume_uL'], 42_000_000);
      expect(payload['currency_code'], 'EUR');

      final remaining = await db.select(db.outbox).get();
      expect(remaining, isEmpty,
          reason: 'applied result must delete the outbox row');
    });

    test('duplicate result also deletes the outbox row '
        '(idempotent retry contract)', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final outbox = OutboxRepository(db);
      final repo = FillUpsRepository(db, outbox: outbox);
      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      await repo.create(
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

      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final mutationId =
            (body['mutations'] as List).first['mutation_id'] as String;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'mutation_id': mutationId,
                'row_id': 'x',
                'row_version': 1,
                'server_updated_at': '2026-05-29T10:00:00Z',
                'status': 'duplicate',
              }
            ],
          }),
          200,
        );
      });
      final client = SyncClient(
        baseUrl: 'http://127.0.0.1:8787',
        bearerToken: 't',
        httpClient: mock,
      );
      addTearDown(client.close);

      final report = await OutboxFlushWorker(outbox: outbox, client: client)
          .flushOnce();
      expect(report.duplicates, 1);
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('5xx leaves the row queued and increments attempts', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicles = VehiclesRepository(db);
      final outbox = OutboxRepository(db);
      final repo = FillUpsRepository(db, outbox: outbox);
      final vehicleId = await vehicles.create(
        const VehicleDraft(name: 'A', fuelType: VehicleFuelType.gasoline),
      );
      await repo.create(
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

      final mock = MockClient(
        (req) async => http.Response('upstream', 503),
      );
      final client = SyncClient(
        baseUrl: 'http://127.0.0.1:8787',
        bearerToken: 't',
        httpClient: mock,
      );
      addTearDown(client.close);

      final report = await OutboxFlushWorker(outbox: outbox, client: client)
          .flushOnce();
      expect(report.retriable, 1);
      expect(report.lastError, contains('503'));

      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1));
      expect(rows.single.attempts, 1);
      expect(rows.single.lastError, contains('503'));
    });

    test('flushOnce on empty outbox is a no-op and never calls HTTP',
        () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db);
      var calls = 0;
      final mock = MockClient((req) async {
        calls += 1;
        return http.Response('{}', 200);
      });
      final client = SyncClient(
        baseUrl: 'http://127.0.0.1:8787',
        bearerToken: 't',
        httpClient: mock,
      );
      addTearDown(client.close);

      final report = await OutboxFlushWorker(outbox: outbox, client: client)
          .flushOnce();
      expect(report.sent, 0);
      expect(calls, 0);
    });
  });
}
