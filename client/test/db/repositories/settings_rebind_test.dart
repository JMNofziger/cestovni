import 'dart:convert';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/sync/settings_rebind.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../_harness.dart';

const _userId = '22222222-2222-4222-8222-222222222222';
const _otherId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _access = 'access-token';

void main() {
  test(
    'server has no settings row: id and pending insert are rewritten',
    () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      await repo.update(timezone: 'America/New_York');
      final before = await db.select(db.outbox).getSingle();
      await db
          .into(db.backupMarks)
          .insert(
            BackupMarksCompanion.insert(
              markedTable: 'settings',
              rowId: before.rowId,
              createdAt: '2026-11-17T00:00:00.000Z',
            ),
          );
      final paths = <String>[];
      final mock = MockClient((req) async {
        paths.add(req.url.path);
        expect(req.headers['authorization'], 'Bearer $_access');
        return _manifest(0);
      });

      await rebindSettingsOnSignIn(
        db: db,
        baseUrl: 'http://127.0.0.1:8080',
        accessToken: _access,
        userId: _userId,
        httpClient: mock,
      );

      expect(paths, ['/api/v1/restore/manifest']);
      final row = await repo.getOrBootstrap();
      expect(row.id, _userId);
      expect(row.timezone, 'America/New_York');
      final pending = await db.select(db.outbox).getSingle();
      expect(pending.mutationId, before.mutationId);
      expect(pending.rowId, _userId);
      expect(pending.attempts, 0);
      expect(pending.lastError, isNull);
      expect(jsonDecode(pending.payloadJson!)['id'], _userId);
      expect((await db.select(db.backupMarks).getSingle()).rowId, _userId);
    },
  );

  test(
    'server has a settings row: restore replaces the bootstrap and sends nothing',
    () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      await repo.update(timezone: 'America/New_York');
      expect(await db.select(db.outbox).get(), hasLength(1));
      final paths = <String>[];
      final mock = MockClient((req) async {
        paths.add(req.url.path);
        if (req.url.path.endsWith('/restore/manifest')) return _manifest(1);
        expect(req.url.queryParameters['table'], 'settings');
        return http.Response(
          jsonEncode({
            'table': 'settings',
            'rows': [_serverSettings()],
            'next_since': 5,
            'has_more': false,
          }),
          200,
        );
      });

      await rebindSettingsOnSignIn(
        db: db,
        baseUrl: 'http://127.0.0.1:8080',
        accessToken: _access,
        userId: _userId,
        httpClient: mock,
      );

      expect(paths, ['/api/v1/restore/manifest', '/api/v1/changes']);
      final row = await repo.getOrBootstrap();
      expect(row.id, _userId);
      expect(row.userId, _userId);
      expect(row.rowVersion, 5);
      expect(row.timezone, 'Europe/Prague');
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('a settings row bound to another account refuses sign-in', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final repo = SettingsRepository(db, server: _BoomServer());
    final original = await repo.getOrBootstrap();
    await db.customStatement(
      'UPDATE settings SET id = ?, user_id = ?, row_version = 4 WHERE id = ?',
      [_otherId, _otherId, original.id],
    );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            mutationId: '33333333-3333-4333-8333-333333333333',
            table_: 'settings',
            op: 'update',
            rowId: _otherId,
            payloadJson: const Value(
              '{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}',
            ),
            enqueuedAt: '2026-11-17T00:00:00.000Z',
            attempts: const Value(2),
          ),
        );

    await expectLater(
      repo.rebindToUser(_userId),
      throwsA(isA<AccountMismatch>()),
    );

    final row = await (db.select(db.appSettings)).getSingle();
    expect(row.id, _otherId);
    expect(row.userId, _otherId);
    expect(row.rowVersion, 4);
    final queued = await db.select(db.outbox).getSingle();
    expect(queued.rowId, _otherId);
    expect(queued.attempts, 2);
    expect(queued.mutationId, '33333333-3333-4333-8333-333333333333');
  });

  test('a dead-lettered random-id insert is rewritten and re-queued', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.update(currencyCode: 'CZK');
    final before = await db.select(db.outbox).getSingle();
    await (db.update(db.outbox)..where((o) => o.id.equals(before.id))).write(
      OutboxCompanion(
        attempts: const Value(6),
        lastError: Value('$outboxDeadLetterPrefix check constraint'),
      ),
    );
    expect(await OutboxRepository(db).pendingBatch(), isEmpty);

    await rebindSettingsOnSignIn(
      db: db,
      baseUrl: 'http://127.0.0.1:8080',
      accessToken: _access,
      userId: _userId,
      httpClient: MockClient((req) async => _manifest(0)),
    );

    final queued = await db.select(db.outbox).getSingle();
    expect(queued.mutationId, before.mutationId);
    expect(queued.rowId, _userId);
    expect(queued.attempts, 0);
    expect(queued.lastError, isNull);
    expect(jsonDecode(queued.payloadJson!)['id'], _userId);
    expect(
      (await OutboxRepository(db).pendingBatch()).single.mutationId,
      before.mutationId,
    );
  });

  test('unsynced and signed out: bootstrap does not enqueue', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    final row = await repo.getOrBootstrap();

    expect(row.userId, isNull);
    expect(row.rowVersion, isNull);
    expect(row.id, isNot(_userId));
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}

class _BoomServer implements SettingsServer {
  @override
  Future<int> settingsRowCount() async {
    throw StateError('manifest must not be read');
  }

  @override
  Future<void> restoreSettings() async {
    throw StateError('restore must not run');
  }
}

http.Response _manifest(int settingsCount) {
  return http.Response(
    jsonEncode({
      'tables': [
        {
          'table': 'settings',
          'row_count': settingsCount,
          'max_row_version': settingsCount == 0 ? 0 : 5,
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _serverSettings() {
  return {
    'id': _userId,
    'user_id': _userId,
    'row_version': 5,
    'updated_at': '2026-10-20T12:00:00.000Z',
    'deleted_at': null,
    'mutation_id': '33333333-3333-4333-8333-333333333333',
    'preferred_distance_unit': 'km',
    'preferred_volume_unit': 'L',
    'currency_code': 'EUR',
    'timezone': 'Europe/Prague',
    'default_vehicle_id': null,
  };
}
