import 'package:drift/drift.dart';

import 'protocol.dart';

/// Mirror of `settings` from docs/specs/data-model.md.
///
/// Exactly one row per user. The `id` column equals the `user_id` —
/// legal because both are UUIDs. Enforced at the app layer (and, on
/// server side, via trigger per the spec).
@DataClassName('SettingsRow')
class AppSettings extends Table with ProtocolColumns {
  TextColumn get preferredDistanceUnit => text()
      .named('preferred_distance_unit')
      .customConstraint(
        "NOT NULL CHECK (preferred_distance_unit IN ('km','mi'))",
      )();

  TextColumn get preferredVolumeUnit => text()
      .named('preferred_volume_unit')
      .customConstraint(
        "NOT NULL CHECK (preferred_volume_unit IN ('L','gal'))",
      )();

  TextColumn get currencyCode =>
      text().named('currency_code').withLength(min: 3, max: 3).customConstraint(
            "NOT NULL CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]')",
          )();

  TextColumn get timezone =>
      text().withLength(min: 1, max: 64)();

  /// Optional FK-by-convention to `vehicles.id` (CES-57). No SQLite FK
  /// constraint on purpose: a stale id (vehicle later soft-deleted or
  /// archived) must remain a legal value here rather than blocking a
  /// settings write. `shell.dart#_seedActiveVehicle` re-validates
  /// against the live vehicle list before honoring it, falling back
  /// to "first vehicle alphabetically" otherwise.
  TextColumn get defaultVehicleId => text()
      .named('default_vehicle_id')
      .nullable()
      .withLength(min: 36, max: 36)();

  @override
  String get tableName => 'settings';

  @override
  Set<Column> get primaryKey => {id};
}
