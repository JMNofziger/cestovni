/// Price-history scatter points grouped by currency.
///
/// Spec: `docs/specs/consumption-math.md` §"Aggregation rules" — price
/// history = scatter of `total_price_cents * 1_000_000 / volume_uL`
/// (cents-per-litre), grouped per vehicle and filtered by currency.
///
/// Pure Dart — no Drift, no Flutter.
library;

import 'models.dart';
import 'rounding.dart';

/// Computes per-fill-up price points grouped by `currency_code`.
///
/// Each [PricePoint.centsPerLitreTenths] is banker's-rounded at the
/// integer division boundary:
///
///     centsPerLitreTenths = divideRoundHalfEven(
///       totalPriceCents * 10_000_000, volumeUL)
///
/// Fill-ups with `volumeUL == 0` are excluded (no price-per-volume is
/// defined).
///
/// Result keys are ISO 4217 currency codes; values are sorted by
/// `(filledAt ASC, id ASC)`.
Map<String, List<PricePoint>> computePriceHistory(
  Iterable<FillUp> fillUps,
) {
  final sorted = fillUps.toList()
    ..sort((a, b) {
      final t = a.filledAt.compareTo(b.filledAt);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    });

  final result = <String, List<PricePoint>>{};

  for (final f in sorted) {
    if (f.volumeUL == 0) continue;

    final centsPerLitreTenths = divideRoundHalfEven(
      f.totalPriceCents * 10000000,
      f.volumeUL,
    );

    result.putIfAbsent(f.currencyCode, () => <PricePoint>[]).add(
      PricePoint(
        fillUpId: f.id,
        filledAt: f.filledAt,
        centsPerLitreTenths: centsPerLitreTenths,
      ),
    );
  }

  return result;
}
