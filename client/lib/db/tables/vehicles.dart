import 'package:drift/drift.dart';

import 'protocol.dart';

/// Mirror of `vehicles` from docs/specs/data-model.md.
///
/// `fuel_type` is a TEXT + CHECK (not a SQL ENUM) per the data-model spec
/// enum discussion; the same constraint is applied on the server side.
@DataClassName('VehicleRow')
class Vehicles extends Table with ProtocolColumns {
  TextColumn get name =>
      text().withLength(min: 1, max: 80)();

  TextColumn get make =>
      text().nullable().withLength(max: 80)();

  TextColumn get model =>
      text().nullable().withLength(max: 80)();

  IntColumn get year => integer().nullable().customConstraint(
        'CHECK (year IS NULL OR (year BETWEEN 1900 AND 2100))',
      )();

  TextColumn get vin =>
      text().nullable().withLength(max: 32)();

  TextColumn get fuelType => text().named('fuel_type').customConstraint(
        "NOT NULL CHECK (fuel_type IN "
        "('gasoline','diesel','lpg','cng','ev_kwh','other'))",
      )();

  /// Canonical µL; optional (informational).
  IntColumn get tankCapacityUL => integer().nullable().named('tank_capacity_uL').customConstraint(
        'CHECK (tank_capacity_uL IS NULL OR tank_capacity_uL >= 0)',
      )();

  TextColumn get archivedAt => text().nullable().named('archived_at')();

  @override
  Set<Column> get primaryKey => {id};
}
