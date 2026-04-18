import 'package:drift/drift.dart';

import 'maintenance_rules.dart';
import 'protocol.dart';
import 'vehicles.dart';

/// Mirror of `maintenance_events` from docs/specs/data-model.md.
@DataClassName('MaintenanceEventRow')
class MaintenanceEvents extends Table with ProtocolColumns {
  TextColumn get vehicleId => text()
      .named('vehicle_id')
      .withLength(min: 36, max: 36)
      .references(Vehicles, #id)();

  /// Nullable — one-off events are allowed (no rule attached).
  TextColumn get ruleId => text()
      .nullable()
      .named('rule_id')
      .withLength(min: 36, max: 36)
      .references(MaintenanceRules, #id)();

  TextColumn get performedAt => text().named('performed_at')();

  IntColumn get odometerM => integer().named('odometer_m').customConstraint(
        'NOT NULL CHECK (odometer_m >= 0)',
      )();

  IntColumn get costCents => integer().named('cost_cents').customConstraint(
        'NOT NULL DEFAULT 0 CHECK (cost_cents >= 0)',
      )();

  TextColumn get currencyCode =>
      text().named('currency_code').withLength(min: 3, max: 3).customConstraint(
            "NOT NULL CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]')",
          )();

  TextColumn get notes => text().nullable().withLength(max: 500)();

  @override
  Set<Column> get primaryKey => {id};
}
