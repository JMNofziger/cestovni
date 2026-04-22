import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

/// Assert that the DB-level constraints from docs/specs/data-model.md
/// are actually enforced by the SQLite schema — i.e. our Drift
/// `customConstraint` lines translate into live CHECK/FK clauses.
void main() {
  group('schema constraints', () {
    test('fill_ups.volume_uL < 0 is rejected', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO fill_ups "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, filled_at, odometer_m, volume_uL, "
          " total_price_cents, currency_code, is_full, missed_before, "
          " odometer_reset) "
          "VALUES (?, ?, 1, ?, ?, ?, ?, 0, -1, 0, 'USD', 0, 0, 0)",
          [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('vehicles.fuel_type must be in the allow-list', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO vehicles "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " name, fuel_type) "
          "VALUES (?, ?, 1, ?, ?, 'Bike', 'unicorn')",
          [newId(), newId(), nowIso(), newId()],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('currency_code must be three uppercase letters', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO fill_ups "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, filled_at, odometer_m, volume_uL, "
          " total_price_cents, currency_code, is_full, missed_before, "
          " odometer_reset) "
          "VALUES (?, ?, 1, ?, ?, ?, ?, 0, 0, 0, 'usd', 1, 0, 0)",
          [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('maintenance_rules requires cadence_km OR cadence_days', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO maintenance_rules "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, name, cadence_km, cadence_days, enabled) "
          "VALUES (?, ?, 1, ?, ?, ?, 'No cadence', NULL, NULL, 1)",
          [newId(), newId(), nowIso(), newId(), vehicleId],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('maintenance_events.category must be in the allow-list', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO maintenance_events "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, performed_at, odometer_m, cost_cents, currency_code, "
          " category) "
          "VALUES (?, ?, 1, ?, ?, ?, ?, 0, 0, 'EUR', 'spa_day')",
          [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('maintenance_events.shop rejects empty string', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO maintenance_events "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, performed_at, odometer_m, cost_cents, currency_code, "
          " category, shop) "
          "VALUES (?, ?, 1, ?, ?, ?, ?, 0, 0, 'EUR', 'oil', '')",
          [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('maintenance_events.odometer_m accepts NULL (optional after CES-53)', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await db.customStatement(
        "INSERT INTO maintenance_events "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, performed_at, odometer_m, cost_cents, currency_code, "
        " category) "
        "VALUES (?, ?, 1, ?, ?, ?, ?, NULL, 0, 'EUR', 'inspection')",
        [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
      );
    });

    test('maintenance_events.cost_cents defaults to 0 when omitted', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);
      final vehicleId = await _seedVehicle(db);

      await db.customStatement(
        "INSERT INTO maintenance_events "
        "(id, user_id, row_version, updated_at, mutation_id, "
        " vehicle_id, performed_at, currency_code, category) "
        "VALUES (?, ?, 1, ?, ?, ?, ?, 'EUR', 'other')",
        [newId(), newId(), nowIso(), newId(), vehicleId, nowIso()],
      );

      final rows = await db
          .customSelect(
            "SELECT cost_cents FROM maintenance_events WHERE vehicle_id = ?",
            variables: [Variable.withString(vehicleId)],
          )
          .get();
      expect(rows.single.read<int>('cost_cents'), 0);
    });

    test('fill_ups.vehicle_id must reference a live vehicle (FK on)', () async {
      final db = openInMemoryDb();
      addTearDown(db.close);

      await expectLater(
        () => db.customStatement(
          "INSERT INTO fill_ups "
          "(id, user_id, row_version, updated_at, mutation_id, "
          " vehicle_id, filled_at, odometer_m, volume_uL, "
          " total_price_cents, currency_code, is_full, missed_before, "
          " odometer_reset) "
          "VALUES (?, ?, 1, ?, ?, ?, ?, 0, 0, 0, 'USD', 1, 0, 0)",
          [newId(), newId(), nowIso(), newId(), 'ghost-vehicle-id', nowIso()],
        ),
        throwsA(isA<Exception>()),
      );
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
