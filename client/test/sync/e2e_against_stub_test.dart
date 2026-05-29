/// CES-44 / CES-43 gate-slice E2E proof — runs the **real**
/// `FillUpsRepository` + `OutboxRepository` + `OutboxFlushWorker`
/// against a live dev sync stub.
///
/// Opt-in by setting `CESTOVNI_E2E=1` so default `flutter test` stays
/// hermetic (no network). Run explicitly:
///
/// ```sh
/// # In one terminal:
/// cd server/dev-sync-stub && node server.js
///
/// # In another:
/// cd client
/// CESTOVNI_E2E=1 flutter test test/sync/e2e_against_stub_test.dart
/// ```
///
/// Override the stub URL / bearer:
///
/// ```sh
/// CESTOVNI_E2E=1 \
/// CESTOVNI_E2E_URL=http://10.0.2.2:8787 \
/// CESTOVNI_E2E_TOKEN=… \
///   flutter test test/sync/e2e_against_stub_test.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/sync/outbox_flush_worker.dart';
import 'package:cestovni/sync/sync_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final isOptedIn = Platform.environment['CESTOVNI_E2E'] == '1';
  test('offline save → outbox enqueue → flush → GET /changes returns the row',
      () async {
    final baseUrl =
        Platform.environment['CESTOVNI_E2E_URL'] ?? 'http://127.0.0.1:8787';
    final bearer =
        Platform.environment['CESTOVNI_E2E_TOKEN'] ?? 'dev-cestovni-token';

    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final vehicles = VehiclesRepository(db);
    final outbox = OutboxRepository(db);
    final fillUps = FillUpsRepository(db, outbox: outbox);

    // Step 1: offline-shaped writes — `create` runs the local insert
    // and outbox enqueue inside one Drift transaction. No network.
    final vehicleId = await vehicles.create(
      const VehicleDraft(
        name: 'E2E Octavia',
        fuelType: VehicleFuelType.gasoline,
      ),
    );
    final rowId = await fillUps.create(
      FillUpDraft(
        vehicleId: vehicleId,
        filledAt: DateTime.utc(2026, 5, 29, 10, 30),
        odometerM: 123_456_000,
        volumeUL: 41_500_000,
        totalPriceCents: 5_876,
        currencyCode: 'EUR',
        isFull: true,
        notes: 'gate-slice E2E proof',
      ),
    );

    final pending = await outbox.pendingBatch();
    expect(pending, hasLength(1));
    final mutationId = pending.single.mutationId;
    expect(pending.single.op, 'insert');

    // ignore: avoid_print
    print('---- cestovni gate E2E ----');
    // ignore: avoid_print
    print('base_url    : $baseUrl');
    // ignore: avoid_print
    print('row_id      : $rowId');
    // ignore: avoid_print
    print('mutation_id : $mutationId');

    // Step 2: drain the outbox against the running stub.
    final client = SyncClient(baseUrl: baseUrl, bearerToken: bearer);
    addTearDown(client.close);
    final worker = OutboxFlushWorker(outbox: outbox, client: client);

    final report = await worker.flushOnce();
    // ignore: avoid_print
    print('flush       : $report');
    expect(report.accepted + report.duplicates, 1,
        reason: 'stub must accept the mutation');
    expect(await outbox.pendingBatch(), isEmpty,
        reason: 'outbox row removed after apply/duplicate');

    // Step 3: verify GET /changes echoes the row back.
    final changes = await http.get(
      Uri.parse('$baseUrl/api/v1/changes?table=fill_ups&since=0'),
      headers: {'Authorization': 'Bearer $bearer'},
    );
    expect(changes.statusCode, 200);
    final body = jsonDecode(changes.body) as Map<String, dynamic>;
    final rows = (body['rows'] as List).cast<Map<String, dynamic>>();
    final mine = rows.firstWhere((r) => r['id'] == rowId,
        orElse: () =>
            throw StateError('row $rowId not returned by GET /changes'));
    expect(mine['odometer_m'], 123_456_000);
    expect(mine['volume_uL'], 41_500_000);
    expect(mine['currency_code'], 'EUR');
    expect(mine['row_version'], isA<int>(),
        reason: 'server hydrated row_version');
    expect(mine['mutation_id'], mutationId);
    // ignore: avoid_print
    print('row_version : ${mine['row_version']}');
    // ignore: avoid_print
    print('---- PASS ----');

    // Step 4: idempotency — replay the same mutation_id via a fresh
    // outbox entry shape, expect duplicate (server dedupe).
    final replay = OutboxRow(
      id: 1,
      mutationId: mutationId,
      table_: 'fill_ups',
      op: 'insert',
      rowId: rowId,
      payloadJson: pending.single.payloadJson,
      enqueuedAt: pending.single.enqueuedAt,
      attempts: 0,
    );
    final retry = await client.postMutations([replay]);
    expect(retry.results.single.status, 'duplicate',
        reason: 'server must dedupe by mutation_id on retry');
  }, skip: isOptedIn ? false : 'set CESTOVNI_E2E=1 + run dev-sync-stub');
}
