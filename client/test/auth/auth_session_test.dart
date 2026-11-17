import 'dart:async';
import 'dart:convert';

import 'package:cestovni/auth/auth_session.dart';
import 'package:cestovni/auth/sync_wiring.dart';
import 'package:cestovni/auth/token_store.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/sync/outbox_flush_worker.dart';
import 'package:cestovni/sync/sync_config.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../db/_harness.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _base = 'http://127.0.0.1:8080';

void main() {
  test('exchange stores the refresh token and emits signedIn', () async {
    final store = MemoryTokenStore();
    final states = <AuthState>[];
    late AuthSession session;
    final mock = MockClient((req) async {
      expect(req.url.path, '/api/v1/auth/google/exchange');
      expect(jsonDecode(req.body), {'code': 'login-code'});
      return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
    });
    session = AuthSession(
      baseUrl: _base,
      store: store,
      httpClient: mock,
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );
    addTearDown(session.close);
    final sub = session.stateStream.listen(states.add);
    addTearDown(sub.cancel);

    final userId = await session.exchange('login-code');

    expect(userId, _userId);
    expect(session.state, isA<SignedIn>());
    final signedIn = session.state as SignedIn;
    expect(signedIn.userId, _userId);
    expect(signedIn.email, 'person@gmail.com');
    expect(states.whereType<SignedIn>(), isNotEmpty);
    expect(await session.bearer(), 'access-1');
    expect(store.values, contains('refresh-1'));
    expect(store.values, contains(_userId));
    expect(store.values, isNot(contains('access-1')));
  });

  test('two concurrent 401s trigger one refreshOnce call', () async {
    final store = MemoryTokenStore();
    final releaseRefresh = Completer<void>();
    var refreshCalls = 0;
    var unauthorized = 0;
    final both401 = Completer<void>();
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/google/exchange')) {
        return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
      }
      if (req.url.path.endsWith('/auth/refresh')) {
        refreshCalls += 1;
        await releaseRefresh.future;
        return _sessionResponse(access: 'access-2', refresh: 'refresh-2');
      }
      final auth = req.headers['authorization'];
      if (auth == 'Bearer access-2') {
        return _applied(_mutationId(req));
      }
      unauthorized += 1;
      if (unauthorized == 2 && !both401.isCompleted) both401.complete();
      return http.Response('no', 401);
    });
    final session = AuthSession(
      baseUrl: _base,
      store: store,
      httpClient: mock,
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );
    addTearDown(session.close);
    final client = syncClientFor(
      const SyncConfig(baseUrl: _base, bearerToken: ''),
      session: session,
      httpClient: mock,
    );
    addTearDown(client.close);
    await session.exchange('login-code');

    final first = client.postMutations([_row(1)]);
    final second = client.postMutations([_row(2)]);
    await both401.future;
    for (var i = 0; i < 10 && refreshCalls == 0; i++) {
      await pumpEventQueue();
    }
    expect(refreshCalls, 1);
    releaseRefresh.complete();
    await Future.wait([first, second]);
    expect(refreshCalls, 1);
    expect(await session.bearer(), 'access-2');
  });

  test('refresh success resumes flush and keeps the outbox row', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    final store = MemoryTokenStore();
    var refreshCalls = 0;
    final sentIds = <String>[];
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/google/exchange')) {
        return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
      }
      if (req.url.path.endsWith('/auth/refresh')) {
        refreshCalls += 1;
        return _sessionResponse(access: 'access-2', refresh: 'refresh-2');
      }
      final id = _mutationId(req);
      sentIds.add(id);
      if (req.headers['authorization'] == 'Bearer access-2') {
        return _applied(id);
      }
      return http.Response('no', 401);
    });
    final session = AuthSession(
      baseUrl: _base,
      store: store,
      httpClient: mock,
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );
    addTearDown(session.close);
    final client = syncClientFor(
      const SyncConfig(baseUrl: _base, bearerToken: ''),
      session: session,
      httpClient: mock,
    );
    addTearDown(client.close);
    final worker = OutboxFlushWorker(outbox: outbox, client: client);
    final sub = session.stateStream.listen((state) {
      if (state is SignedIn) worker.clearAuthPause();
    });
    addTearDown(sub.cancel);
    await session.exchange('login-code');

    final report = await worker.flushOnce();

    expect(refreshCalls, 1);
    expect(sentIds, [
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(report.authPaused, isFalse);
    expect(report.accepted, 1);
    expect(worker.authPaused, isFalse);
    expect(await outbox.pendingBatch(), isEmpty);
  });

  test('401 refresh_invalid clears the session and emits signedOut', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await _seed(db);
    final store = MemoryTokenStore();
    final states = <AuthState>[];
    var exchanges = 0;
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/auth/google/exchange')) {
        exchanges += 1;
        return _sessionResponse(
          access: 'access-$exchanges',
          refresh: 'refresh-$exchanges',
        );
      }
      if (req.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'refresh_invalid',
              'message': 'no',
              'retriable': false,
            },
          }),
          401,
        );
      }
      return http.Response('no', 401);
    });
    final session = AuthSession(
      baseUrl: _base,
      store: store,
      httpClient: mock,
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );
    addTearDown(session.close);
    final sub = session.stateStream.listen(states.add);
    addTearDown(sub.cancel);
    final client = syncClientFor(
      const SyncConfig(baseUrl: _base, bearerToken: ''),
      session: session,
      httpClient: mock,
    );
    addTearDown(client.close);
    final worker = OutboxFlushWorker(outbox: outbox, client: client);
    final pauseSub = session.stateStream.listen((state) {
      if (state is SignedIn) worker.clearAuthPause();
    });
    addTearDown(pauseSub.cancel);
    await session.exchange('login-code');

    final report = await worker.flushOnce();

    expect(report.authPaused, isTrue);
    expect(worker.authPaused, isTrue);
    expect(session.state, isA<SignedOut>());
    expect(states.whereType<SignedOut>(), isNotEmpty);
    expect(store.values, isNot(contains('refresh-1')));
    expect((await db.select(db.outbox).get()).single.attempts, 0);
    expect(await outbox.pendingBatch(), hasLength(1));

    await session.exchange('login-code-2');
    expect(session.state, isA<SignedIn>());
    expect(worker.authPaused, isFalse);
    expect(await outbox.pendingBatch(), hasLength(1));
  });

  test(
    'network failure on refresh keeps the session and stays retriable',
    () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db);
      await _seed(db);
      final store = MemoryTokenStore();
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/auth/google/exchange')) {
          return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
        }
        if (req.url.path.endsWith('/auth/refresh')) {
          throw http.ClientException('offline');
        }
        return http.Response('no', 401);
      });
      final session = AuthSession(
        baseUrl: _base,
        store: store,
        httpClient: mock,
        clock: () => DateTime.utc(2026, 11, 17, 12),
      );
      addTearDown(session.close);
      final client = syncClientFor(
        const SyncConfig(baseUrl: _base, bearerToken: ''),
        session: session,
        httpClient: mock,
      );
      addTearDown(client.close);
      final worker = OutboxFlushWorker(outbox: outbox, client: client);
      await session.exchange('login-code');

      final report = await worker.flushOnce();

      expect(session.state, isA<SignedIn>());
      expect(store.values, contains('refresh-1'));
      expect(report.authPaused, isFalse);
      expect(report.retriable, 1);
      expect(report.deadLettered, 0);
      expect(await outbox.pendingBatch(), hasLength(1));
    },
  );

  test('logging works with no session and sync skips', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    final vehicles = VehiclesRepository(db);
    var calls = 0;
    final mock = MockClient((req) async {
      calls += 1;
      return http.Response('no', 500);
    });
    final store = MemoryTokenStore();
    final session = AuthSession(baseUrl: _base, store: store, httpClient: mock);
    addTearDown(session.close);
    await session.ready;
    final client = syncClientFor(
      const SyncConfig(baseUrl: _base, bearerToken: ''),
      session: session,
      httpClient: mock,
    );
    addTearDown(client.close);
    final worker = OutboxFlushWorker(outbox: outbox, client: client);

    await vehicles.create(
      const VehicleDraft(name: 'Local', fuelType: VehicleFuelType.gasoline),
    );
    expect(await session.bearer(), isNull);
    expect(session.state, isA<SignedOut>());

    final report = await worker.flushOnce();

    expect(calls, 0);
    expect(report.sent, 0);
    expect(report.lastError, 'no session');
    expect(await outbox.pendingBatch(), isNotEmpty);
  });

  test(
    'signOut clears storage and emits signedOut when logout fails',
    () async {
      final store = MemoryTokenStore();
      final states = <AuthState>[];
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/auth/google/exchange')) {
          return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
        }
        throw http.ClientException('offline');
      });
      final session = AuthSession(
        baseUrl: _base,
        store: store,
        httpClient: mock,
        clock: () => DateTime.utc(2026, 11, 17, 12),
      );
      addTearDown(session.close);
      final sub = session.stateStream.listen(states.add);
      addTearDown(sub.cancel);
      await session.exchange('login-code');

      await session.signOut();

      expect(session.state, isA<SignedOut>());
      expect(states.whereType<SignedOut>(), isNotEmpty);
      expect(store.map, isEmpty);
      expect(await session.bearer(), isNull);
    },
  );

  test('signedIn is reported only after beforeSignedIn finishes', () async {
    final store = MemoryTokenStore();
    final started = Completer<void>();
    final release = Completer<void>();
    final states = <AuthState>[];
    late AuthSession session;
    final mock = MockClient((req) async {
      return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
    });
    session = AuthSession(
      baseUrl: _base,
      store: store,
      httpClient: mock,
      clock: () => DateTime.utc(2026, 11, 17, 12),
      beforeSignedIn: (userId, accessToken) async {
        expect(userId, _userId);
        expect(accessToken, 'access-1');
        expect(session.state, isA<SignedOut>());
        started.complete();
        await release.future;
      },
    );
    addTearDown(session.close);
    final sub = session.stateStream.listen(states.add);
    addTearDown(sub.cancel);

    final pending = session.exchange('login-code');
    await started.future;
    expect(session.state, isA<SignedOut>());
    expect(states.whereType<SignedIn>(), isEmpty);
    release.complete();
    expect(await pending, _userId);

    expect(session.state, isA<SignedIn>());
    expect(states.whereType<SignedIn>(), isNotEmpty);
    expect(await session.bearer(), 'access-1');
  });

  test(
    'AccountMismatch clears the new session and reports signedOut',
    () async {
      final store = MemoryTokenStore();
      final states = <AuthState>[];
      final mock = MockClient((req) async {
        return _sessionResponse(access: 'access-1', refresh: 'refresh-1');
      });
      final session = AuthSession(
        baseUrl: _base,
        store: store,
        httpClient: mock,
        clock: () => DateTime.utc(2026, 11, 17, 12),
        beforeSignedIn: (userId, accessToken) async {
          throw const AccountMismatch();
        },
      );
      addTearDown(session.close);
      final sub = session.stateStream.listen(states.add);
      addTearDown(sub.cancel);

      await expectLater(
        session.exchange('login-code'),
        throwsA(isA<AccountMismatch>()),
      );

      expect(session.state, isA<SignedOut>());
      expect(states.whereType<SignedIn>(), isEmpty);
      expect(store.map, isEmpty);
      expect(await session.bearer(), isNull);
    },
  );
}

class MemoryTokenStore implements TokenStore {
  final map = <String, String>{};

  Iterable<String> get values => map.values;

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

http.Response _sessionResponse({
  required String access,
  required String refresh,
}) {
  return http.Response(
    jsonEncode({
      'user_id': _userId,
      'email': 'person@gmail.com',
      'access_token': access,
      'token_type': 'Bearer',
      'expires_in': 900,
      'refresh_token': refresh,
      'refresh_expires_in': 5184000,
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _applied(String mutationId) {
  return http.Response(
    jsonEncode({
      'results': [
        {
          'mutation_id': mutationId,
          'status': 'applied',
          'row_id': '22222222-2222-4222-8222-222222222222',
          'row_version': 1,
          'server_updated_at': '2026-11-17T12:00:00Z',
        },
      ],
    }),
    200,
  );
}

String _mutationId(http.Request req) {
  final body = jsonDecode(req.body) as Map<String, dynamic>;
  final first = (body['mutations'] as List).first as Map<String, dynamic>;
  return first['mutation_id'] as String;
}

OutboxRow _row(int id) {
  return OutboxRow(
    id: id,
    mutationId: '11111111-1111-4111-8111-11111111111$id',
    table_: 'vehicles',
    op: 'insert',
    rowId: '22222222-2222-4222-8222-222222222222',
    payloadJson: '{"name":"A"}',
    enqueuedAt: '2026-11-17T12:00:00.000Z',
    attempts: 0,
  );
}

Future<void> _seed(AppDatabase db) {
  return db
      .into(db.outbox)
      .insert(
        OutboxCompanion.insert(
          mutationId: '11111111-1111-4111-8111-111111111111',
          table_: 'vehicles',
          op: 'insert',
          rowId: '22222222-2222-4222-8222-222222222222',
          payloadJson: const Value('{"name":"A"}'),
          enqueuedAt: '2026-11-17T12:00:00.000Z',
        ),
      );
}
