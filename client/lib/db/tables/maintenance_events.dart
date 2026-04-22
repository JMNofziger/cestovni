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

  /// Optional. UX allows leaving odometer blank on maintenance entries
  /// (oil change at the shop with no dashboard reading at hand).
  /// Cost stays mandatory at the schema level — the form writes 0 when
  /// the user leaves it empty (DATA_CONTRACTS.md §Maintenance). See
  /// [CES-53](https://linear.app/personal-interests-llc/issue/CES-53).
  IntColumn get odometerM => integer().nullable().named('odometer_m').customConstraint(
        'CHECK (odometer_m IS NULL OR odometer_m >= 0)',
      )();

  IntColumn get costCents => integer().named('cost_cents').customConstraint(
        'NOT NULL DEFAULT 0 CHECK (cost_cents >= 0)',
      )();

  TextColumn get currencyCode =>
      text().named('currency_code').withLength(min: 3, max: 3).customConstraint(
            "NOT NULL CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]')",
          )();

  /// Maintenance category. Closed enum mirrored in DATA_CONTRACTS.md
  /// so the form and the metrics bucketing stay in lockstep. Added in
  /// schema v2 with a `'other'` default so v1 rows round-trip cleanly
  /// through the 0002 migration.
  TextColumn get category => text().named('category').customConstraint(
        "NOT NULL DEFAULT 'other' CHECK (category IN "
        "('oil','tires','brakes','inspection','battery','fluid','other'))",
      )();

  /// Optional shop / vendor name (free text). Added in v2.
  TextColumn get shop => text().nullable().customConstraint(
        'CHECK (shop IS NULL OR length(shop) BETWEEN 1 AND 120)',
      )();

  TextColumn get notes => text().nullable().withLength(max: 500)();

  @override
  Set<Column> get primaryKey => {id};
}
