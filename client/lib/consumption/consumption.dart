/// Segment partitioning + per-segment + lifetime consumption math.
///
/// Spec: `docs/specs/consumption-math.md` (CES-38). Pure Dart; see
/// `adapters.dart` for the Drift boundary.
///
/// Phase 1 scope (this file as shipped in the first phase of CES-38):
/// - `computeSegments` handles lineage partitioning, (prev_full, next_full]
///   segments, partial inclusion, missed_before → unknown, degenerate
///   D == 0, and trailing-partial discard.
/// - `computeLifetime` sums known segments only.
/// - Per-segment `lPer100kmTenths` and `centsPerKmTenths` are computed.
///
/// Phase 2 will add trailing-12m windowing and the multi-fixture runner
/// exercises. Price-history lives in `price_history.dart`.
library;

import 'models.dart';
import 'rounding.dart';

/// Compute all closed consumption segments for one vehicle.
///
/// `fillUps` can be in any order; this function sorts defensively by
/// `(filledAt ASC, id ASC)` per spec §62. Returns segments in close
/// order (same as closing-full order). Unknown / degenerate segments are
/// emitted with their status so UX / lifetime math can choose to skip
/// them without losing visibility.
List<SegmentOutcome> computeSegments(Iterable<FillUp> fillUps) {
  final sorted = fillUps.toList(growable: false)
    ..sort((a, b) {
      final t = a.filledAt.compareTo(b.filledAt);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    });

  if (sorted.isEmpty) return const <SegmentOutcome>[];

  final outcomes = <SegmentOutcome>[];

  FillUp? prevFull;
  final pendingPartials = <FillUp>[];

  for (final f in sorted) {
    if (f.odometerReset) {
      prevFull = null;
      pendingPartials.clear();
      if (f.isFull) {
        prevFull = f;
      } else {
        pendingPartials.add(f);
      }
      continue;
    }

    if (prevFull == null) {
      if (f.isFull) {
        prevFull = f;
      } else {
        pendingPartials.add(f);
      }
      continue;
    }

    if (f.isFull) {
      final inclusive = <FillUp>[...pendingPartials, f];
      outcomes.add(_closeSegment(prevFull, f, inclusive));
      prevFull = f;
      pendingPartials.clear();
    } else {
      pendingPartials.add(f);
    }
  }

  return outcomes;
}

SegmentOutcome _closeSegment(
  FillUp prevFull,
  FillUp nextFull,
  List<FillUp> inclusive,
) {
  final distanceM = nextFull.odometerM - prevFull.odometerM;

  var volumeUL = 0;
  var costCents = 0;
  var hasMissed = false;
  for (final f in inclusive) {
    if (f.missedBefore) hasMissed = true;
    volumeUL += f.volumeUL;
    // Issue B (CES-51): segment cost aggregates only rows matching the closing
    // full's currency; other-currency partials drop out of cost but still
    // appear in price_history_by_currency.
    if (f.currencyCode == nextFull.currencyCode) {
      costCents += f.totalPriceCents;
    }
  }

  final SegmentStatus status;
  if (hasMissed) {
    status = SegmentStatus.unknownMissed;
  } else if (distanceM == 0) {
    status = SegmentStatus.degenerateZeroDistance;
  } else if (distanceM < 0) {
    status = SegmentStatus.unknownResetBoundary;
  } else {
    status = SegmentStatus.known;
  }

  final int? lPer100kmTenths = (status == SegmentStatus.known)
      ? divideRoundHalfEven(volumeUL, distanceM)
      : null;

  final int? centsPerKmTenths = (distanceM > 0)
      ? divideRoundHalfEven(costCents * 10000, distanceM)
      : null;

  return SegmentOutcome(
    prevFullId: prevFull.id,
    nextFullId: nextFull.id,
    status: status,
    distanceM: distanceM,
    volumeUL: volumeUL,
    costCents: costCents,
    closedAt: nextFull.filledAt,
    lPer100kmTenths: lPer100kmTenths,
    centsPerKmTenths: centsPerKmTenths,
  );
}

/// Vehicle-lifetime aggregate. Unknown / degenerate segments excluded
/// from both numerator and denominator of `lPer100kmTenths` per spec
/// §105. Total spend is summed per currency across ALL non-deleted
/// fill-ups (including partials outside any segment and leading/trailing
/// tails) so surfaces like "total spend" don't surprise the user by
/// hiding money.
LifetimeConsumption computeLifetime(
  Iterable<SegmentOutcome> segments, {
  Iterable<FillUp> allFillUps = const <FillUp>[],
}) {
  var totalDistanceM = 0;
  var totalVolumeUL = 0;
  for (final s in segments) {
    if (s.status != SegmentStatus.known) continue;
    totalDistanceM += s.distanceM;
    totalVolumeUL += s.volumeUL;
  }

  final int? lPer100kmTenths = (totalDistanceM > 0)
      ? divideRoundHalfEven(totalVolumeUL, totalDistanceM)
      : null;

  final totalSpend = <String, int>{};
  for (final f in allFillUps) {
    totalSpend[f.currencyCode] =
        (totalSpend[f.currencyCode] ?? 0) + f.totalPriceCents;
  }

  return LifetimeConsumption(
    lPer100kmTenths: lPer100kmTenths,
    totalDistanceM: totalDistanceM,
    totalVolumeUL: totalVolumeUL,
    totalSpendCentsByCurrency: totalSpend,
  );
}
