/// Entry-time fill-up validation.
///
/// Spec: `docs/specs/consumption-math.md` §"Validation rules at entry".
/// Pure Dart — no Drift, no Flutter.
library;

import 'models.dart';

/// Validates a candidate fill-up against the existing fill-up history for
/// the same vehicle.
///
/// Returns `null` if the candidate passes all rules; otherwise returns the
/// first failing [ValidationFailure]. Rules are checked in priority order
/// (cheapest / most fundamental first):
///
///   1. Non-negative canonical fields.
///   2. `filled_at` not in the future (+ 24 h tolerance).
///   3. `odometer_reset` on the very first fill-up.
///   4. Odometer regression within the same lineage.
ValidationFailure? validateInsert(
  FillUp candidate,
  List<FillUp> existingForVehicle,
  DateTime nowUtc,
) {
  if (candidate.odometerM < 0) {
    return const ValidationFailure(ValidationErrorCode.odometerNegative);
  }
  if (candidate.volumeUL < 0) {
    return const ValidationFailure(ValidationErrorCode.volumeNegative);
  }
  if (candidate.totalPriceCents < 0) {
    return const ValidationFailure(ValidationErrorCode.priceNegative);
  }

  final futureLimit = nowUtc.add(const Duration(hours: 24));
  if (candidate.filledAt.isAfter(futureLimit)) {
    return const ValidationFailure(ValidationErrorCode.filledAtInFuture);
  }

  if (candidate.odometerReset && existingForVehicle.isEmpty) {
    return const ValidationFailure(ValidationErrorCode.resetOnFirstFillup);
  }

  if (!candidate.odometerReset && existingForVehicle.isNotEmpty) {
    final prev = _latestInSameLineage(existingForVehicle, candidate);
    if (prev != null && candidate.odometerM < prev.odometerM) {
      return const ValidationFailure(ValidationErrorCode.odometerRegression);
    }
  }

  return null;
}

/// Finds the most recent fill-up in the same odometer lineage (no reset
/// between it and the candidate) that precedes the candidate's `filledAt`.
FillUp? _latestInSameLineage(List<FillUp> existing, FillUp candidate) {
  final sorted = existing.toList()
    ..sort((a, b) {
      final t = a.filledAt.compareTo(b.filledAt);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    });

  FillUp? latest;
  for (final f in sorted) {
    if (f.odometerReset) {
      latest = null;
    }
    final cmp = f.filledAt.compareTo(candidate.filledAt);
    if (cmp > 0 || (cmp == 0 && f.id.compareTo(candidate.id) >= 0)) break;
    latest = f;
  }
  return latest;
}
