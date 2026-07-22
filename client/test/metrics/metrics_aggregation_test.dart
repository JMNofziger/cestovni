import 'package:cestovni/consumption/models.dart';
import 'package:cestovni/metrics/metrics_aggregation.dart';
import 'package:flutter_test/flutter_test.dart';

FillUp _fill({
  required String id,
  required DateTime filledAt,
  required int odometerM,
  int volumeUL = 40000000,
  int totalPriceCents = 6000,
  String currencyCode = 'EUR',
  bool isFull = true,
  bool missedBefore = false,
}) {
  return FillUp(
    id: id,
    vehicleId: 'v1',
    filledAt: filledAt,
    odometerM: odometerM,
    volumeUL: volumeUL,
    totalPriceCents: totalPriceCents,
    currencyCode: currencyCode,
    isFull: isFull,
    missedBefore: missedBefore,
  );
}

void main() {
  group('metricsWindowStartUtc', () {
    final nowUtc = DateTime.utc(2026, 7, 22, 13);

    test('ALL has no start', () {
      expect(metricsWindowStartUtc(MetricsRange.all, nowUtc), isNull);
    });

    test('30D = start of civil day 29 days back (UTC)', () {
      expect(
        metricsWindowStartUtc(MetricsRange.d30, nowUtc),
        DateTime.utc(2026, 6, 23),
      );
    });

    test('90D = start of civil day 89 days back (UTC)', () {
      expect(
        metricsWindowStartUtc(MetricsRange.d90, nowUtc),
        DateTime.utc(2026, 4, 24),
      );
    });

    test('YTD = Jan 1 of the current civil year (UTC)', () {
      expect(
        metricsWindowStartUtc(MetricsRange.ytd, nowUtc),
        DateTime.utc(2026),
      );
    });

    test('tz offset shifts civil boundaries', () {
      // 23:30Z on Jul 22 is already Jul 23 in UTC+2, so the 30-day
      // window starts on civil Jun 24 → 22:00Z Jun 23.
      final lateUtc = DateTime.utc(2026, 7, 22, 23, 30);
      expect(
        metricsWindowStartUtc(
          MetricsRange.d30,
          lateUtc,
          tzOffset: const Duration(hours: 2),
        ),
        DateTime.utc(2026, 6, 23, 22),
      );
      // YTD in UTC+2 starts at Dec 31 22:00Z of the previous year.
      expect(
        metricsWindowStartUtc(
          MetricsRange.ytd,
          lateUtc,
          tzOffset: const Duration(hours: 2),
        ),
        DateTime.utc(2026, 1, 1).subtract(const Duration(hours: 2)),
      );
    });
  });

  group('computeMetricsSummary — window filtering', () {
    final start = DateTime.utc(2026, 6, 23);

    test('boundary instant is inclusive; earlier instants excluded', () {
      final atBoundary = _fill(
        id: 'a',
        filledAt: start,
        odometerM: 50000000,
        totalPriceCents: 1000,
      );
      final justBefore = _fill(
        id: 'b',
        filledAt: start.subtract(const Duration(milliseconds: 1)),
        odometerM: 49000000,
        totalPriceCents: 2000,
      );
      final summary =
          computeMetricsSummary([justBefore, atBoundary], start);
      expect(summary.fillUpCount, 1);
      expect(summary.spendCentsByCurrency, {'EUR': 1000});
      expect(summary.costSeriesByCurrency['EUR']!.single.fillUpId, 'a');
    });

    test('null start (ALL) includes everything', () {
      final fills = [
        _fill(id: 'a', filledAt: DateTime.utc(2024), odometerM: 1000000),
        _fill(id: 'b', filledAt: DateTime.utc(2026), odometerM: 2000000),
      ];
      expect(computeMetricsSummary(fills, null).fillUpCount, 2);
    });

    test('segment closed in-window counts even if it opened outside', () {
      final older = _fill(
        id: 'a',
        filledAt: start.subtract(const Duration(days: 5)),
        odometerM: 50000000,
        totalPriceCents: 1000,
      );
      final inWindow = _fill(
        id: 'b',
        filledAt: start.add(const Duration(days: 1)),
        odometerM: 50600000,
        volumeUL: 45000000,
        totalPriceCents: 7000,
      );
      final summary = computeMetricsSummary([older, inWindow], start);
      // Distance from the (a → b] segment, attributed to closing fill.
      expect(summary.distanceM, 600000);
      expect(summary.volumeUL, 45000000);
      // Spend only counts in-window fill-ups.
      expect(summary.spendCentsByCurrency, {'EUR': 7000});
    });
  });

  group('computeMetricsSummary — lifetime totals', () {
    test('distance, spend, and economy across full fills', () {
      final fills = [
        _fill(
          id: 'a',
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 50000000,
          volumeUL: 40000000,
          totalPriceCents: 6000,
        ),
        _fill(
          id: 'b',
          filledAt: DateTime.utc(2026, 6, 1),
          odometerM: 50600000,
          volumeUL: 45000000,
          totalPriceCents: 7000,
        ),
        _fill(
          id: 'c',
          filledAt: DateTime.utc(2026, 7, 1),
          odometerM: 51200000,
          volumeUL: 42000000,
          totalPriceCents: 6500,
        ),
      ];
      final summary = computeMetricsSummary(fills, null);
      expect(summary.fillUpCount, 3);
      expect(summary.distanceM, 1200000);
      expect(summary.volumeUL, 87000000);
      expect(summary.spendCentsByCurrency, {'EUR': 19500});
      // 87 L / 1 200 km = 7.25 → banker's tie → 72 tenths.
      expect(summary.lPer100kmTenths, 72);
      expect(summary.seriesPointCount, 3);
      expect(summary.isLowData, isFalse);
    });

    test('no fills → empty summary, low data', () {
      final summary = computeMetricsSummary(const [], null);
      expect(summary.fillUpCount, 0);
      expect(summary.distanceM, 0);
      expect(summary.lPer100kmTenths, isNull);
      expect(summary.isLowData, isTrue);
    });
  });

  group('computeMetricsSummary — economy segment rules', () {
    test('trailing partial adds spend but no segment', () {
      final base = [
        _fill(
          id: 'a',
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 50000000,
        ),
        _fill(
          id: 'b',
          filledAt: DateTime.utc(2026, 6, 1),
          odometerM: 50600000,
          volumeUL: 45000000,
        ),
      ];
      final withPartial = [
        ...base,
        _fill(
          id: 'c',
          filledAt: DateTime.utc(2026, 6, 15),
          odometerM: 50900000,
          volumeUL: 20000000,
          totalPriceCents: 3000,
          isFull: false,
        ),
      ];
      final noPartial = computeMetricsSummary(base, null);
      final partial = computeMetricsSummary(withPartial, null);
      expect(partial.distanceM, noPartial.distanceM);
      expect(partial.volumeUL, noPartial.volumeUL);
      expect(partial.lPer100kmTenths, noPartial.lPer100kmTenths);
      expect(partial.spendCentsByCurrency['EUR'],
          noPartial.spendCentsByCurrency['EUR']! + 3000);
      expect(partial.fillUpCount, 3);
    });

    test('missed-before segment excluded from economy but not spend', () {
      final fills = [
        _fill(
          id: 'a',
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 50000000,
        ),
        _fill(
          id: 'b',
          filledAt: DateTime.utc(2026, 6, 1),
          odometerM: 50600000,
          missedBefore: true,
        ),
      ];
      final summary = computeMetricsSummary(fills, null);
      expect(summary.distanceM, 0);
      expect(summary.lPer100kmTenths, isNull);
      expect(summary.spendCentsByCurrency, {'EUR': 12000});
    });
  });

  group('computeMetricsSummary — low data + currencies', () {
    test('single point in range → low data', () {
      final summary = computeMetricsSummary([
        _fill(id: 'a', filledAt: DateTime.utc(2026, 7, 1), odometerM: 1000),
      ], null);
      expect(summary.seriesPointCount, 1);
      expect(summary.isLowData, isTrue);
    });

    test('mixed currencies split into one series per currency', () {
      final fills = [
        _fill(
          id: 'a',
          filledAt: DateTime.utc(2026, 5, 1),
          odometerM: 50000000,
          totalPriceCents: 6000,
        ),
        _fill(
          id: 'b',
          filledAt: DateTime.utc(2026, 6, 1),
          odometerM: 50600000,
          totalPriceCents: 15000,
          currencyCode: 'CZK',
        ),
      ];
      final summary = computeMetricsSummary(fills, null);
      expect(summary.spendCentsByCurrency, {'EUR': 6000, 'CZK': 15000});
      expect(summary.costSeriesByCurrency.keys.toSet(), {'EUR', 'CZK'});
      expect(summary.costSeriesByCurrency['EUR'], hasLength(1));
      expect(summary.costSeriesByCurrency['CZK'], hasLength(1));
    });

    test('series is ascending by filledAt', () {
      final fills = [
        _fill(id: 'b', filledAt: DateTime.utc(2026, 6, 1), odometerM: 2000),
        _fill(id: 'a', filledAt: DateTime.utc(2026, 5, 1), odometerM: 1000),
      ];
      final series =
          computeMetricsSummary(fills, null).costSeriesByCurrency['EUR']!;
      expect(series.map((p) => p.fillUpId), ['a', 'b']);
    });
  });
}
