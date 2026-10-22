import 'dart:convert';

import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/sync/restore_apply.dart';
import 'package:cestovni/sync/restore_service.dart';
import 'package:cestovni/sync/sync_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../db/_harness.dart';

const _user = '22222222-2222-4222-8222-222222222222';
const _mutation = '33333333-3333-4333-8333-333333333333';
const _vehicle = '11111111-1111-4111-8111-111111111111';
const _fillA = '44444444-4444-4444-8444-444444444441';
const _fillB = '44444444-4444-4444-8444-444444444442';
const _rule = '55555555-5555-4555-8555-555555555555';
const _event = '66666666-6666-4666-8666-666666666666';

void main() {
  test('restore converges and a second run does not duplicate rows', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    await SettingsRepository(db, enqueue: false).getOrBootstrap();
    final server = _Server(_fixture());
    final client = _client(server);
    addTearDown(client.close);

    final done = await RestoreService(db: db, client: client)
        .run(reason: RestoreReason.userInitiated)
        .last;
    expect(done.phase, RestoreRunPhase.complete);
    expect(done.coreReady, isTrue);
    await _expectMatches(db, server);

    final again = await RestoreService(db: db, client: client)
        .run(reason: RestoreReason.reinstall)
        .last;
    expect(again.phase, RestoreRunPhase.complete);
    expect(again.rowsApplied, 0);
    await _expectMatches(db, server);
  });

  test('a failed page resumes from the committed cursor', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final server = _Server({
      'vehicles': [_vehicleRow(_vehicle, 1)],
      'fill_ups': [
        _fillRow(_fillA, 2),
        _fillRow(_fillB, 3),
      ],
      'maintenance_rules': const [],
      'maintenance_events': const [],
      'settings': const [],
    });
    server.failOnChangesCall = 3;
    final client = _client(server, pageLimit: 1);
    addTearDown(client.close);
    final service = RestoreService(db: db, client: client, pageLimit: 1);
    final failed = await service.run(reason: RestoreReason.coldStart).last;
    expect(failed.phase, RestoreRunPhase.failed);
    expect(await RestoreApplier(db).cursorFor('vehicles'), 1);
    expect(await RestoreApplier(db).cursorFor('fill_ups'), 2);
    expect(await db.select(db.fillUps).get(), hasLength(1));

    server.failOnChangesCall = null;
    final resumed = await RestoreService(db: db, client: client, pageLimit: 1)
        .run(reason: RestoreReason.userInitiated)
        .last;
    expect(resumed.phase, RestoreRunPhase.complete);
    final fills = await db.select(db.fillUps).get();
    expect(fills.map((r) => r.id).toSet(), {_fillA, _fillB});
    expect(await RestoreApplier(db).cursorFor('fill_ups'), 3);
  });

  test('replaying a page does not duplicate rows', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final applier = RestoreApplier(db);
    final row = _vehicleRow(_vehicle, 4, name: 'Server');
    await applier.applyPage(table: 'vehicles', rows: [row], nextSince: 4);
    await applier.applyPage(table: 'vehicles', rows: [row], nextSince: 4);
    expect(await db.select(db.vehicles).get(), hasLength(1));
    expect(await applier.cursorFor('vehicles'), 4);
  });

  test('server row wins on the same id; other local rows stay', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final vehicles = VehiclesRepository(db);
    final same = await vehicles.create(
      const VehicleDraft(name: 'Local', fuelType: VehicleFuelType.gasoline),
    );
    await db.customStatement(
      'UPDATE vehicles SET id = ? WHERE id = ?',
      [_vehicle, same],
    );
    await db.customStatement(
      'UPDATE outbox SET row_id = ? WHERE row_id = ?',
      [_vehicle, same],
    );
    final other = await vehicles.create(
      const VehicleDraft(name: 'Mine', fuelType: VehicleFuelType.diesel),
    );

    await RestoreApplier(db).applyPage(
      table: 'vehicles',
      rows: [_vehicleRow(_vehicle, 9, name: 'Server')],
      nextSince: 9,
    );

    final rows = await db.select(db.vehicles).get();
    final byId = {for (final row in rows) row.id: row};
    expect(byId[_vehicle]!.name, 'Server');
    expect(byId[_vehicle]!.rowVersion, 9);
    expect(byId[other]!.name, 'Mine');
    expect(byId[other]!.rowVersion, isNull);
    final pending = await db.select(db.outbox).get();
    expect(pending.map((r) => r.rowId), [other]);
  });

  test('cancel stops before writing and keeps the device usable', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final local = await VehiclesRepository(db, enqueue: false).create(
      const VehicleDraft(name: 'Offline', fuelType: VehicleFuelType.gasoline),
    );
    final server = _Server(_fixture());
    final client = _client(server);
    addTearDown(client.close);
    final service = RestoreService(db: db, client: client);
    service.cancel();
    final snap = await service.run(reason: RestoreReason.coldStart).last;
    expect(snap.phase, RestoreRunPhase.cancelled);
    expect((await db.select(db.vehicles).get()).single.id, local);
  });
}

Future<void> _expectMatches(dynamic db, _Server server) async {
  final vehicles = await db.select(db.vehicles).get();
  expect(vehicles.single.id, _vehicle);
  expect(vehicles.single.rowVersion, 1);
  expect(vehicles.single.name, 'Octavia');

  final fills = await db.select(db.fillUps).get();
  expect(fills.single.id, _fillA);
  expect(fills.single.rowVersion, 2);
  expect(fills.single.volumeUL, 42000000);

  final rules = await db.select(db.maintenanceRules).get();
  expect(rules.single.cadenceM, 10000);
  final events = await db.select(db.maintenanceEvents).get();
  expect(events.single.category, 'oil');

  final settings = await db.select(db.appSettings).get();
  expect(settings, hasLength(1));
  expect(settings.single.id, _user);
  expect(settings.single.userId, _user);
  expect(settings.single.timezone, 'Europe/Prague');
  expect(server.rows['settings']!.single['id'], _user);
}

SyncClient _client(_Server server, {int pageLimit = 200}) {
  return SyncClient(
    baseUrl: 'http://127.0.0.1:8080',
    bearerToken: 't',
    httpClient: MockClient((req) => server.handle(req, pageLimit: pageLimit)),
  );
}

class _Server {
  _Server(this.rows);
  final Map<String, List<Map<String, dynamic>>> rows;
  int? failOnChangesCall;
  int _changes = 0;

  Future<http.Response> handle(http.Request req, {required int pageLimit}) async {
    if (req.url.path.endsWith('/restore/manifest')) {
      return _json({
        'tables': [
          for (final name in restoreTableOrder)
            {
              'table': name,
              'row_count': rows[name]!.length,
              'max_row_version': rows[name]!.isEmpty
                  ? 0
                  : rows[name]!
                      .map((r) => r['row_version'] as int)
                      .reduce((a, b) => a > b ? a : b),
            },
        ],
      });
    }
    _changes += 1;
    if (failOnChangesCall == _changes) {
      return http.Response('upstream', 503);
    }
    final table = req.url.queryParameters['table']!;
    final since = int.parse(req.url.queryParameters['since'] ?? '0');
    final limit = int.parse(req.url.queryParameters['limit'] ?? '$pageLimit');
    final pending = rows[table]!
        .where((r) => (r['row_version'] as int) > since)
        .toList()
      ..sort(
        (a, b) => (a['row_version'] as int).compareTo(b['row_version'] as int),
      );
    final page = pending.take(limit).toList();
    return _json({
      'table': table,
      'rows': page,
      'next_since': page.isEmpty ? since : page.last['row_version'],
      'has_more': pending.length > limit,
    });
  }

  http.Response _json(Object body) => http.Response(jsonEncode(body), 200);
}

Map<String, List<Map<String, dynamic>>> _fixture() {
  return {
    'vehicles': [_vehicleRow(_vehicle, 1, name: 'Octavia')],
    'fill_ups': [_fillRow(_fillA, 2)],
    'maintenance_rules': [
      {
        'id': _rule,
        'user_id': _user,
        'row_version': 3,
        'updated_at': '2026-10-20T12:00:00.000Z',
        'deleted_at': null,
        'mutation_id': _mutation,
        'vehicle_id': _vehicle,
        'name': 'oil',
        'cadence_m': 10000,
        'cadence_days': 180,
        'enabled': true,
        'notes': null,
      },
    ],
    'maintenance_events': [
      {
        'id': _event,
        'user_id': _user,
        'row_version': 4,
        'updated_at': '2026-10-20T12:00:00.000Z',
        'deleted_at': null,
        'mutation_id': _mutation,
        'vehicle_id': _vehicle,
        'rule_id': _rule,
        'performed_at': '2026-07-01T00:00:00.000Z',
        'odometer_m': 1000,
        'cost_cents': 500,
        'currency_code': 'EUR',
        'category': 'oil',
        'shop': null,
        'notes': null,
      },
    ],
    'settings': [
      {
        'id': _user,
        'user_id': _user,
        'row_version': 5,
        'updated_at': '2026-10-20T12:00:00.000Z',
        'deleted_at': null,
        'mutation_id': _mutation,
        'preferred_distance_unit': 'km',
        'preferred_volume_unit': 'L',
        'currency_code': 'EUR',
        'timezone': 'Europe/Prague',
        'default_vehicle_id': _vehicle,
      },
    ],
  };
}

Map<String, dynamic> _vehicleRow(String id, int version, {String name = 'Server'}) {
  return {
    'id': id,
    'user_id': _user,
    'row_version': version,
    'updated_at': '2026-10-20T12:00:00.000Z',
    'deleted_at': null,
    'mutation_id': _mutation,
    'name': name,
    'make': null,
    'model': null,
    'year': null,
    'vin': null,
    'fuel_type': 'gasoline',
    'tank_capacity_uL': null,
    'archived_at': null,
  };
}

Map<String, dynamic> _fillRow(String id, int version) {
  return {
    'id': id,
    'user_id': _user,
    'row_version': version,
    'updated_at': '2026-10-20T12:00:00.000Z',
    'deleted_at': null,
    'mutation_id': _mutation,
    'vehicle_id': _vehicle,
    'filled_at': '2026-04-03T08:00:00.000Z',
    'odometer_m': 1000,
    'volume_uL': 42000000,
    'total_price_cents': 6100,
    'currency_code': 'EUR',
    'is_full': true,
    'missed_before': false,
    'odometer_reset': false,
    'notes': null,
  };
}
