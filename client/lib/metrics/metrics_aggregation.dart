/// Pure aggregation layer for the Metrics tab (CES-66).
///
/// Spec: `docs/product/ux/DATA_CONTRACTS.md` §"Metrics contract (MVP)"
/// + `docs/specs/consumption-math.md`. Range windows (30D / 90D / YTD /
/// ALL) are built as civil dates in the user's timezone and compared
/// against the stored UTC instants, per §"Filters and metrics".
///
/// Economy reuses `client/lib/consumption/` segment math — full-fill
/// segments only; unknown/degenerate segments are omitted from the
/// average. This module MUST NOT reimplement segment math.
///
/// Pure Dart — no Flutter or Drift imports.
library;

import '../consumption/consumption.dart';
import '../consumption/models.dart';
import '../consumption/rounding.dart';

/// Supported metric ranges per the Metrics contract.
enum MetricsRange { d30, d90, ytd, all }

/// Short UI label (`30D` / `90D` / `YTD` / `ALL`).
String metricsRangeLabel(MetricsRange range) => switch (range) {
      MetricsRange.d30 => '30D',
      MetricsRange.d90 => '90D',
      MetricsRange.ytd => 'YTD',
      MetricsRange.all => 'ALL',
    };

/// Inclusive UTC start instant for [range], or `null` for ALL.
///
/// Boundaries are civil-date based in the user's timezone, expressed
/// here as a fixed [tzOffset] from UTC: `30D` = start of the civil day
/// 29 days before "today" (a rolling window that includes today), `90D`
/// likewise with 89, `YTD` = Jan 1 of the current civil year. The
/// returned instant is UTC so callers can compare directly against
/// stored `filled_at` values (`filledAt >= start`).
DateTime? metricsWindowStartUtc(
  MetricsRange range,
  DateTime nowUtc, {
  Duration tzOffset = Duration.zero,
}) {
  if (range == MetricsRange.all) return null;
  // `DateTime.utc` is used as a zone-less container for civil wall
  // time so device-local zone rules never leak into the math.
  final DateTime local = nowUtc.toUtc().add(tzOffset);
  final DateTime today = DateTime.utc(local.year, local.month, local.day);
  final DateTime startLocal = switch (range) {
    MetricsRange.d30 => today.subtract(const Duration(days: 29)),
    MetricsRange.d90 => today.subtract(const Duration(days: 89)),
    MetricsRange.ytd => DateTime.utc(local.year),
    MetricsRange.all => throw StateError('unreachable'),
  };
  return startLocal.subtract(tzOffset);
}

/// One point on the cost-over-time chart.
class CostPoint {
  const CostPoint({
    required this.fillUpId,
    required this.filledAt,
    required this.totalPriceCents,
  });

  final String fillUpId;
  final DateTime filledAt;
  final int totalPriceCents;
}

/// Aggregates for one vehicle within one range window.
class MetricsSummary {
  const MetricsSummary({
    required this.fillUpCount,
    required this.distanceM,
    required this.volumeUL,
    required this.lPer100kmTenths,
    required this.spendCentsByCurrency,
    required this.costSeriesByCurrency,
  });

  /// Live fill-ups whose `filledAt` falls inside the window.
  final int fillUpCount;

  /// Distance across **known** segments closed inside the window.
  final int distanceM;

  /// Volume across **known** segments closed inside the window.
  final int volumeUL;

  /// Economy across known in-window segments; `null` = "—".
  final int? lPer100kmTenths;

  /// Sum of `total_price_cents` per currency for in-window fill-ups
  /// (all fill-ups count toward spend, including partials).
  final Map<String, int> spendCentsByCurrency;

  /// Cost-over-time series per currency, ascending `(filledAt, id)`.
  final Map<String, List<CostPoint>> costSeriesByCurrency;

  /// Total chart points across all currencies.
  int get seriesPointCount =>
      costSeriesByCurrency.values.fold(0, (sum, s) => sum + s.length);

  /// Low-data rule per the Metrics contract: fewer than 2 points for
  /// a trend → render the layout-preserving placeholder.
  bool get isLowData => seriesPointCount < 2;
}

/// Compute the Metrics summary for one vehicle.
///
/// [fillUps] must be the vehicle's **complete** live history (all
/// non-deleted rows) — segments need full lineage even when the
/// window only shows the tail. [startUtc] is the inclusive window
/// start from [metricsWindowStartUtc] (`null` = ALL).
///
/// Windowing rules:
/// - Spend + chart series: fill-ups with `filledAt >= startUtc`.
/// - Distance / volume / economy: segments whose closing full fill
///   (`closedAt`) is inside the window. Attributing a segment to its
///   closing fill keeps every segment counted exactly once as the
///   window slides.
///
/// Chart series shape: one point per fill-up (`filledAt`,
/// `total_price_cents`), **not** cumulative and not bucketed — the
/// simplest faithful "cost over time" reading of the mock; bucketing
/// variants are a Later per `DELIVERY_ACCEPTANCE.md`. Mixed
/// currencies produce one series per currency (deep multi-currency
/// handling is CES-51).
MetricsSummary computeMetricsSummary(
  Iterable<FillUp> fillUps,
  DateTime? startUtc,
) {
  final List<FillUp> all = fillUps.toList(growable: false);

  bool inWindow(DateTime t) => startUtc == null || !t.isBefore(startUtc);

  final List<FillUp> windowed = all
      .where((f) => inWindow(f.filledAt))
      .toList(growable: false)
    ..sort((a, b) {
      final t = a.filledAt.compareTo(b.filledAt);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    });

  final spend = <String, int>{};
  final series = <String, List<CostPoint>>{};
  for (final f in windowed) {
    spend[f.currencyCode] = (spend[f.currencyCode] ?? 0) + f.totalPriceCents;
    series.putIfAbsent(f.currencyCode, () => <CostPoint>[]).add(CostPoint(
          fillUpId: f.id,
          filledAt: f.filledAt,
          totalPriceCents: f.totalPriceCents,
        ));
  }

  var distanceM = 0;
  var volumeUL = 0;
  for (final s in computeSegments(all)) {
    if (s.status != SegmentStatus.known) continue;
    if (!inWindow(s.closedAt)) continue;
    distanceM += s.distanceM;
    volumeUL += s.volumeUL;
  }

  return MetricsSummary(
    fillUpCount: windowed.length,
    distanceM: distanceM,
    volumeUL: volumeUL,
    lPer100kmTenths:
        distanceM > 0 ? divideRoundHalfEven(volumeUL, distanceM) : null,
    spendCentsByCurrency: spend,
    costSeriesByCurrency: series,
  );
}
