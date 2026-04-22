/// Pure-Dart value objects for the consumption module.
///
/// Spec: `docs/specs/consumption-math.md` (CES-38).
///
/// This file MUST NOT import `package:drift/*` or `package:flutter/*`.
/// Drift rows are mapped in `adapters.dart` only (see Issue A — tracking
/// revisit of module dep direction).
library;

/// A fill-up in canonical SI-INT64 units.
///
/// Ordering for math: `(filledAt ASC, id ASC)`. `filledAt` is UTC.
class FillUp {
  const FillUp({
    required this.id,
    required this.vehicleId,
    required this.filledAt,
    required this.odometerM,
    required this.volumeUL,
    required this.totalPriceCents,
    required this.currencyCode,
    required this.isFull,
    this.missedBefore = false,
    this.odometerReset = false,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final DateTime filledAt;
  final int odometerM;
  final int volumeUL;
  final int totalPriceCents;
  final String currencyCode;
  final bool isFull;
  final bool missedBefore;
  final bool odometerReset;
  final String? notes;
}

/// Status of a single consumption segment.
///
/// `known` — both endpoints full, same lineage, no missed fills, D > 0.
/// `unknownMissed` — any fill in the inclusive closing set has
/// `missed_before = true`; excluded from lifetime numerator & denominator.
/// `unknownResetBoundary` — reserved for defensive cases (e.g. negative
/// distance that should have been blocked by validation). Not expected in
/// v1 fixtures; kept so invariants can be asserted.
/// `degenerateZeroDistance` — two full fill-ups at the same odometer;
/// surfaced to UX so the user can fix the entry.
enum SegmentStatus {
  known,
  unknownMissed,
  unknownResetBoundary,
  degenerateZeroDistance,
}

/// A closed segment `(prevFull, nextFull]` within one odometer lineage.
class SegmentOutcome {
  const SegmentOutcome({
    required this.prevFullId,
    required this.nextFullId,
    required this.status,
    required this.distanceM,
    required this.volumeUL,
    required this.costCents,
    required this.closedAt,
    required this.lPer100kmTenths,
    required this.centsPerKmTenths,
  });

  final String prevFullId;
  final String nextFullId;
  final SegmentStatus status;
  final int distanceM;
  final int volumeUL;

  /// Sum of `total_price_cents` for the segment's inclusive closing set,
  /// restricted to rows matching the closing full's `currency_code`.
  /// See Issue B for the planned revisit of multi-currency behaviour.
  final int costCents;

  final DateTime closedAt;

  /// Null iff `status != known`.
  final int? lPer100kmTenths;

  /// Emitted even for unknown segments (UX may choose to hide). Null only
  /// when `distanceM == 0` (degenerate).
  final int? centsPerKmTenths;
}

/// Lifetime / windowed consumption aggregate.
///
/// `lPer100kmTenths == null` means "—" (no known segments); callers must
/// not coerce to 0.
class LifetimeConsumption {
  const LifetimeConsumption({
    required this.lPer100kmTenths,
    required this.totalDistanceM,
    required this.totalVolumeUL,
    required this.totalSpendCentsByCurrency,
  });

  final int? lPer100kmTenths;
  final int totalDistanceM;
  final int totalVolumeUL;
  final Map<String, int> totalSpendCentsByCurrency;
}

/// A single scatter point on the price-history chart (per currency).
class PricePoint {
  const PricePoint({
    required this.fillUpId,
    required this.filledAt,
    required this.centsPerLitreTenths,
  });

  final String fillUpId;
  final DateTime filledAt;
  final int centsPerLitreTenths;
}

/// Typed error codes for entry-time validation (§"Validation rules at
/// entry" in `docs/specs/consumption-math.md`). Stable on-wire strings;
/// server mirrors these. Do not rename without a migration note.
enum ValidationErrorCode {
  odometerNegative('ODOMETER_NEGATIVE'),
  volumeNegative('VOLUME_NEGATIVE'),
  priceNegative('PRICE_NEGATIVE'),
  filledAtInFuture('FILLED_AT_IN_FUTURE'),
  odometerRegression('ODOMETER_REGRESSION'),
  resetOnFirstFillup('RESET_ON_FIRST_FILLUP');

  const ValidationErrorCode(this.wire);

  final String wire;

  static ValidationErrorCode fromWire(String wire) {
    for (final c in ValidationErrorCode.values) {
      if (c.wire == wire) return c;
    }
    throw ArgumentError.value(wire, 'wire', 'unknown ValidationErrorCode');
  }
}

/// Returned by `validateInsert`. Non-null return = reject.
class ValidationFailure {
  const ValidationFailure(this.code, {this.message});

  final ValidationErrorCode code;
  final String? message;

  @override
  String toString() =>
      'ValidationFailure(${code.wire}${message == null ? '' : ': $message'})';
}
