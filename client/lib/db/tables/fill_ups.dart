import 'package:drift/drift.dart';

import 'protocol.dart';
import 'vehicles.dart';

/// Mirror of `fill_ups` from docs/specs/data-model.md.
///
/// All canonical physical columns are INT64 per docs/specs/si-units.md:
/// `volume_uL` (µL), `odometer_m` (m), `total_price_cents` (cents).
///
/// Foreign key to `vehicles.id` is intentionally NOT `ON DELETE CASCADE`:
/// vehicles are soft-deleted, their fill-up history remains. The FK is
/// defined via `customConstraint` because we also need `NOT NULL`.
@DataClassName('FillUpRow')
class FillUps extends Table with ProtocolColumns {
  TextColumn get vehicleId => text()
      .named('vehicle_id')
      .withLength(min: 36, max: 36)
      .references(Vehicles, #id)();

  TextColumn get filledAt => text().named('filled_at')();

  IntColumn get odometerM => integer().named('odometer_m').customConstraint(
        'NOT NULL CHECK (odometer_m >= 0)',
      )();

  IntColumn get volumeUL => integer().named('volume_uL').customConstraint(
        'NOT NULL CHECK (volume_uL >= 0)',
      )();

  IntColumn get totalPriceCents =>
      integer().named('total_price_cents').customConstraint(
            'NOT NULL CHECK (total_price_cents >= 0)',
          )();

  TextColumn get currencyCode =>
      text().named('currency_code').withLength(min: 3, max: 3).customConstraint(
            "NOT NULL CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]')",
          )();

  BoolColumn get isFull => boolean().named('is_full')();

  BoolColumn get missedBefore =>
      boolean().named('missed_before').withDefault(const Constant(false))();

  BoolColumn get odometerReset =>
      boolean().named('odometer_reset').withDefault(const Constant(false))();

  TextColumn get notes => text().nullable().withLength(max: 500)();

  @override
  Set<Column> get primaryKey => {id};
}
