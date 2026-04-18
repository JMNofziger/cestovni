import 'package:drift/drift.dart';

import 'protocol.dart';
import 'vehicles.dart';

/// Mirror of `maintenance_rules` from docs/specs/data-model.md.
///
/// Table-level CHECK: at least one of `cadence_km` / `cadence_days`
/// must be non-null (enforced in SQLite via the `customConstraints`
/// override below).
@DataClassName('MaintenanceRuleRow')
class MaintenanceRules extends Table with ProtocolColumns {
  TextColumn get vehicleId => text()
      .named('vehicle_id')
      .withLength(min: 36, max: 36)
      .references(Vehicles, #id)();

  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Canonical meters.
  IntColumn get cadenceKm => integer().nullable().named('cadence_km').customConstraint(
        'CHECK (cadence_km IS NULL OR cadence_km > 0)',
      )();

  IntColumn get cadenceDays => integer().nullable().named('cadence_days').customConstraint(
        'CHECK (cadence_days IS NULL OR cadence_days > 0)',
      )();

  BoolColumn get enabled =>
      boolean().withDefault(const Constant(true))();

  TextColumn get notes => text().nullable().withLength(max: 500)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (cadence_km IS NOT NULL OR cadence_days IS NOT NULL)',
      ];
}
