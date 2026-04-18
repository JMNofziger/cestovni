import 'package:drift/drift.dart';

/// Client-only `drafts` table from docs/specs/data-model.md
/// (§ "Client-only tables"). In-progress fill-ups not yet promoted
/// to `fill_ups`. Never outboxed; never exported.
///
/// Carries **no** protocol columns (ADR 002 does not apply — purely local).
/// Boolean-ish columns are stored as INTEGER NULL per the spec.
@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();

  TextColumn get vehicleId => text().nullable().named('vehicle_id').withLength(min: 36, max: 36)();

  TextColumn get createdAt => text().named('created_at')();

  TextColumn get filledAt => text().nullable().named('filled_at')();

  IntColumn get odometerM => integer().nullable().named('odometer_m').customConstraint(
        'CHECK (odometer_m IS NULL OR odometer_m >= 0)',
      )();

  IntColumn get volumeUL => integer().nullable().named('volume_uL').customConstraint(
        'CHECK (volume_uL IS NULL OR volume_uL >= 0)',
      )();

  IntColumn get totalPriceCents =>
      integer().nullable().named('total_price_cents').customConstraint(
            'CHECK (total_price_cents IS NULL OR total_price_cents >= 0)',
          )();

  TextColumn get currencyCode =>
      text().nullable().named('currency_code').withLength(min: 3, max: 3)();

  IntColumn get isFull => integer().nullable().named('is_full')();

  IntColumn get missedBefore => integer().nullable().named('missed_before')();

  IntColumn get odometerReset => integer().nullable().named('odometer_reset')();

  TextColumn get notes => text().nullable().withLength(max: 500)();

  /// Set when promoted; drives photo 7-day post-completion TTL.
  TextColumn get completedAt => text().nullable().named('completed_at')();

  @override
  Set<Column> get primaryKey => {id};
}
