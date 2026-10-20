import 'dart:convert';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/sync/outbox_flush_worker.dart';
import 'package:cestovni/sync/sync_client.dart';
import 'package:drift/drift.dart';
// Transitive through flutter_test; the client has no direct fake_async dep.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../db/_harness.dart';

void main() {
  test('backoff is 1, 2, 4, 8, 16, 30 seconds with ±20% jitter', () {
    const exact = <int, int>{1: 1, 2: 2, 3: 4, 4: 8, 5: 16, 6: 30, 9: 30};
    for (final entry in exact.entries) {
      expect(
        syncBackoff(entry.key, randomUnit: () => 0.5),
        Duration(seconds: entry.value),
      );
    }
    final low = syncBackoff(1, randomUnit: () => 0);
    final high = syncBackoff(1, randomUnit: () => 1);
    expect(low.inMilliseconds, 800);
    expect(high.inMilliseconds, 1200);
  });

  test('429 honors Retry-After and does not dead-letter after six tries',
      () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    var calls = 0;
    final mock = MockClient((req) async {
      calls += 1;
      return http.Response(
        'slow down',
        429,
        headers: {'retry-after': '9'},
      );
    });
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    final worker = OutboxFlushWorker(
      outbox: outbox,
      client: client,
      randomUnit: () => 0.5,
    );

    for (var i = 0; i < 7; i++) {
      final report = await worker.flushOnce();
      expect(report.retryAfterSeconds, 9);
      expect(report.retriable, 1);
      expect(report.deadLettered, 0);
    }
    expect(calls, 7);
    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempts, 7);
    expect(row.lastError, isNot(startsWith(outboxDeadLetterPrefix)));
    expect(await outbox.pendingBatch(), hasLength(1));
  });

  test('six non-429 failures dead-letter the row; a seventh does not send',
      () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    var calls = 0;
    final mock = MockClient((req) async {
      calls += 1;
      return http.Response('upstream', 503);
    });
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    final worker = OutboxFlushWorker(outbox: outbox, client: client);

    for (var i = 0; i < 5; i++) {
      final report = await worker.flushOnce();
      expect(report.deadLettered, 0);
      expect(report.retriable, 1);
    }
    final sixth = await worker.flushOnce();
    expect(sixth.deadLettered, 1);
    expect(sixth.retriable, 0);
    expect(calls, 6);

    final seventh = await worker.flushOnce();
    expect(seventh.sent, 0);
    expect(calls, 6);
    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempts, 6);
    expect(row.lastError, startsWith(outboxDeadLetterPrefix));
    expect(await outbox.pendingBatch(), isEmpty);
  });

  test('HTTP 400 dead-letters immediately', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    final mock = MockClient((req) async => http.Response('bad', 400));
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    final report =
        await OutboxFlushWorker(outbox: outbox, client: client).flushOnce();
    expect(report.deadLettered, 1);
    expect(report.retriable, 0);
    final row = (await db.select(db.outbox).get()).single;
    expect(row.attempts, 1);
    expect(row.lastError, startsWith(outboxDeadLetterPrefix));
  });

  test('HTTP 401 pauses automatic flush and does not burn attempts', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    var calls = 0;
    final mock = MockClient((req) async {
      calls += 1;
      return http.Response('nope', 401);
    });
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    final now = DateTime.utc(2026, 10, 20, 12);
    final worker = OutboxFlushWorker(
      outbox: outbox,
      client: client,
      clock: () => now,
    );

    final first = await worker.flushOnce();
    expect(first.authPaused, isTrue);
    expect(calls, 1);
    expect((await db.select(db.outbox).get()).single.attempts, 0);

    final skipped = await worker.flushOnce(manual: false);
    expect(skipped.authPaused, isTrue);
    expect(skipped.sent, 0);
    expect(calls, 1);

    final manual = await worker.flushOnce();
    expect(manual.authPaused, isTrue);
    expect(calls, 2);
  });

  test('automatic flush waits out the backoff; manual does not', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    var calls = 0;
    final mock = MockClient((req) async {
      calls += 1;
      return http.Response('upstream', 503);
    });
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    final now = DateTime.utc(2026, 10, 20, 12);
    final worker = OutboxFlushWorker(
      outbox: outbox,
      client: client,
      clock: () => now,
      randomUnit: () => 0.5,
    );

    await worker.flushOnce(manual: false);
    expect(calls, 1);
    final skipped = await worker.flushOnce(manual: false);
    expect(skipped.sent, 0);
    expect(calls, 1);
    await worker.flushOnce();
    expect(calls, 2);
  });

  test('periodic flush fires on the interval and stop cancels it', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    await _seed(db);
    final outbox = OutboxRepository(db);
    var calls = 0;
    late SyncClient client;
    late OutboxFlushWorker worker;
    fakeAsync((async) {
      final mock = MockClient((req) async {
        calls += 1;
        return http.Response(
          jsonEncode({'results': []}),
          200,
        );
      });
      client = SyncClient(
        baseUrl: 'http://127.0.0.1:8080',
        bearerToken: 't',
        httpClient: mock,
      );
      worker = OutboxFlushWorker(outbox: outbox, client: client);
      worker.startPeriodicFlush();
      async.elapse(const Duration(seconds: 29));
      expect(calls, 0);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(calls, 1);

      worker.stopPeriodicFlush();
      async.elapse(const Duration(seconds: 90));
      expect(calls, 1);
    });
    worker.stopPeriodicFlush();
    client.close();
  });
}

Future<void> _seed(AppDatabase db) {
  return db.into(db.outbox).insert(
        OutboxCompanion.insert(
          mutationId: '11111111-1111-4111-8111-111111111111',
          table_: 'vehicles',
          op: 'insert',
          rowId: '22222222-2222-4222-8222-222222222222',
          payloadJson: const Value('{"id":"22222222-2222-4222-8222-222222222222"}'),
          enqueuedAt: '2026-10-20T12:00:00.000Z',
        ),
      );
}
