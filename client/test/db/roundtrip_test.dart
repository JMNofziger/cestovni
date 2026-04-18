import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

/// Round-trip one row per table per docs/specs/data-model.md. We drive
/// SQL directly rather than Drift DAOs so the test verifies the *schema
/// shape* (NOT NULL, CHECK, FK, defaults) rather than the generated
/// Dart façade — which is what CES-37 actually specifies.
void main() {
  group('round-trip inserts per v1 table', () {
    test('vehicles', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      final id = newId();
      final userId = newId();
      await db.customStatement(
        "INSERT INTO vehicles "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " name, fuel_type) "
        "VALUES (?, ?, ?, ?, ?, ?, 'gasoline')",
        [id, userId, 42, nowIso(), newId(), 'Škoda Octavia'],
      );

      final rows = await db
          .customSelect('SELECT name, fuel_type, row_version FROM vehicles')
          .get();
      expect(rows.length, 1);
      expect(rows.first.read<String>('name'), 'Škoda Octavia');
      expect(rows.first.read<String>('fuel_type'), 'gasoline');
      expect(rows.first.read<int>('row_version'), 42);
    });

    test('fill_ups: INT64 canonical columns persist losslessly', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      final vehicleId = await _seedVehicle(db);

      // Deliberately huge but INT64-safe values — si-units.md §"Overflow
      // headroom test" demands these fit.
      const volumeUL = 10000 * 1000000; // 10 000 L in µL
      const odometerM = 10000000 * 1000; // 10 000 000 km in m
      const priceCents = 10000000 * 100; // $10 000 000 in cents

      final id = newId();
      await db.customStatement(
        "INSERT INTO fill_ups "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, filled_at, odometer_m, volume_uL, "
        " total_price_cents, currency_code, is_full, missed_before, "
        " odometer_reset) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'EUR', 1, 0, 0)",
        [id, newId(), 1, nowIso(), newId(), vehicleId, nowIso(),
          odometerM, volumeUL, priceCents],
      );

      final row = await db
          .customSelect(
            'SELECT volume_uL, odometer_m, total_price_cents, is_full '
            'FROM fill_ups',
          )
          .getSingle();
      expect(row.read<int>('volume_uL'), volumeUL);
      expect(row.read<int>('odometer_m'), odometerM);
      expect(row.read<int>('total_price_cents'), priceCents);
      expect(row.read<int>('is_full'), 1);
    });

    test('maintenance_rules: cadence_km or cadence_days required', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await db.customStatement(
        "INSERT INTO maintenance_rules "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, name, cadence_km, cadence_days, enabled) "
        "VALUES (?, ?, ?, ?, ?, ?, 'Oil change', 15000000, NULL, 1)",
        [newId(), newId(), 1, nowIso(), newId(), vehicleId],
      );

      final rows =
          await db.customSelect('SELECT name FROM maintenance_rules').get();
      expect(rows.single.read<String>('name'), 'Oil change');
    });

    test('maintenance_events: nullable rule_id for one-off events', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await db.customStatement(
        "INSERT INTO maintenance_events "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, rule_id, performed_at, odometer_m, cost_cents, "
        " currency_code) "
        "VALUES (?, ?, ?, ?, ?, ?, NULL, ?, 0, 0, 'USD')",
        [newId(), newId(), 1, nowIso(), newId(), vehicleId, nowIso()],
      );

      final row = await db
          .customSelect(
            'SELECT rule_id, cost_cents, currency_code FROM maintenance_events',
          )
          .getSingle();
      expect(row.data['rule_id'], isNull);
      expect(row.read<int>('cost_cents'), 0);
      expect(row.read<String>('currency_code'), 'USD');
    });

    test('settings: single row per user', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      final userId = newId();
      await db.customStatement(
        "INSERT INTO settings "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " preferred_distance_unit, preferred_volume_unit, "
        " currency_code, timezone) "
        "VALUES (?, ?, 1, ?, ?, 'km', 'L', 'EUR', 'Europe/Prague')",
        [userId, userId, nowIso(), newId()],
      );

      final row = await db
          .customSelect('SELECT preferred_distance_unit, timezone FROM settings')
          .getSingle();
      expect(row.read<String>('preferred_distance_unit'), 'km');
      expect(row.read<String>('timezone'), 'Europe/Prague');
    });

    test('drafts: client-only; booleans stored as INTEGER NULL', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO drafts "
        "(id, created_at, is_full, missed_before, odometer_reset) "
        "VALUES (?, ?, NULL, NULL, NULL)",
        [newId(), nowIso()],
      );

      final row = await db
          .customSelect('SELECT is_full, missed_before, odometer_reset FROM drafts')
          .getSingle();
      expect(row.data['is_full'], isNull);
      expect(row.data['missed_before'], isNull);
      expect(row.data['odometer_reset'], isNull);
    });

    test('outbox: auto-increment id; client-only', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final rowId = newId();

      await db.customStatement(
        'INSERT INTO outbox '
        '("table", op, mutation_id, row_id, enqueued_at) '
        "VALUES ('fill_ups', 'insert', ?, ?, ?)",
        [newId(), rowId, nowIso()],
      );
      await db.customStatement(
        'INSERT INTO outbox '
        '("table", op, mutation_id, row_id, enqueued_at, payload_json) '
        "VALUES ('vehicles', 'update', ?, ?, ?, '{}')",
        [newId(), newId(), nowIso()],
      );

      final rows = await db
          .customSelect('SELECT id, "table", attempts FROM outbox ORDER BY id')
          .get();
      expect(rows.length, 2);
      expect(rows[0].read<int>('id'), 1);
      expect(rows[1].read<int>('id'), 2);
      expect(rows[0].read<int>('attempts'), 0);
      expect(rows[1].read<String>('table'), 'vehicles');
    });

    test('photo_refs: client-only; sha256 + ttl persist', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      final draftId = newId();
      await db.customStatement(
        'INSERT INTO drafts (id, created_at) VALUES (?, ?)',
        [draftId, nowIso()],
      );

      await db.customStatement(
        "INSERT INTO photo_refs "
        "(id, draft_id, captured_at, byte_size, sha256, ttl_expires_at) "
        "VALUES (?, ?, ?, 204800, ?, ?)",
        [
          newId(),
          draftId,
          nowIso(),
          // 64 hex chars (SHA-256).
          '0' * 64,
          DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
        ],
      );

      final row = await db
          .customSelect('SELECT byte_size, sha256 FROM photo_refs')
          .getSingle();
      expect(row.read<int>('byte_size'), 204800);
      expect(row.read<String>('sha256'), '0' * 64);
    });
  });
}

Future<String> _seedVehicle(dynamic db) async {
  final id = newId();
  await db.customStatement(
    "INSERT INTO vehicles "
    "(id, user_id, row_version, updated_at, mutation_id, "
    " name, fuel_type) "
    "VALUES (?, ?, 1, ?, ?, 'Seed', 'gasoline')",
    [id, newId(), nowIso(), newId()],
  );
  return id;
}
