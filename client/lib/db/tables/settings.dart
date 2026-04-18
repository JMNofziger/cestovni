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

  @override
  String get tableName => 'settings';

  @override
  Set<Column> get primaryKey => {id};
}
