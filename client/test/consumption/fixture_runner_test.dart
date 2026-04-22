/// Auto-discovery fixture runner for `tests/math/fixtures/*.json`.
///
/// Spec: `docs/specs/consumption-math.md` (CES-38).
///
/// Discovers every `.json` file in `tests/math/fixtures/` at test time
/// and dispatches by `expected.kind`:
///   - `segments` → compute segments + lifetime + price_history, assert
///     structural equality.
///   - `validation_rejection` → call `validateInsert` and assert the
///     typed error code matches.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cestovni/consumption/consumption.dart';
import 'package:cestovni/consumption/models.dart';
import 'package:cestovni/consumption/price_history.dart';
import 'package:cestovni/consumption/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturesDir = _resolveFixturesDir();

  test(
    'fixtures directory is discoverable from the test context',
    () {
      expect(
        fixturesDir.existsSync(),
        isTrue,
        reason:
            'tests/math/fixtures/ must resolve relative to the test file. '
            'Looked at: ${fixturesDir.path}',
      );
      expect(
        fixturesDir.listSync().whereType<File>().length,
        greaterThanOrEqualTo(20),
        reason: 'Phase 1 ships 20 fixtures; count regressed.',
      );
    },
  );

  final fixtureFiles = fixturesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in fixtureFiles) {
    final basename = _basename(file.path);
    final fixture =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = fixture['name'] as String? ?? basename;

    test('fixture $basename ($name)', () {
      _assertFixture(fixture);
    });
  }
}

void _assertFixture(Map<String, dynamic> fixture) {
  final input = fixture['input'] as Map<String, dynamic>;
  final expected = fixture['expected'] as Map<String, dynamic>;
  final kind = expected['kind'] as String;

  switch (kind) {
    case 'segments':
      _assertSegmentsFixture(input, expected);
    case 'validation_rejection':
      _assertValidationRejection(input, expected);
    default:
      fail('unknown expected.kind: $kind');
  }
}

// ---------------------------------------------------------------------------
// Segments + lifetime + price_history
// ---------------------------------------------------------------------------

void _assertSegmentsFixture(
  Map<String, dynamic> input,
  Map<String, dynamic> expected,
) {
  final fillUps = (input['fillups'] as List)
      .map((raw) => _parseFillUp(raw as Map<String, dynamic>))
      .toList(growable: false);

  final segments = computeSegments(fillUps);
  final lifetime = computeLifetime(segments, allFillUps: fillUps);

  // --- segments ---
  final expectedSegments =
      (expected['segments'] as List).cast<Map<String, dynamic>>();
  expect(
    segments.length,
    expectedSegments.length,
    reason: 'segment count mismatch',
  );
  for (var i = 0; i < segments.length; i++) {
    final actual = segments[i];
    final want = expectedSegments[i];
    expect(actual.prevFullId, want['prev_full_id'],
        reason: 'segment[$i].prev_full_id');
    expect(actual.nextFullId, want['next_full_id'],
        reason: 'segment[$i].next_full_id');
    expect(_statusToWire(actual.status), want['status'],
        reason: 'segment[$i].status');
    expect(actual.distanceM, want['distance_m'],
        reason: 'segment[$i].distance_m');
    expect(actual.volumeUL, want['volume_uL'],
        reason: 'segment[$i].volume_uL');
    expect(actual.costCents, want['cost_cents'],
        reason: 'segment[$i].cost_cents');
    expect(actual.lPer100kmTenths, want['l_per_100km_tenths'],
        reason: 'segment[$i].l_per_100km_tenths');
    expect(actual.centsPerKmTenths, want['cents_per_km_tenths'],
        reason: 'segment[$i].cents_per_km_tenths');
    expect(
      actual.closedAt,
      DateTime.parse(want['closed_at'] as String).toUtc(),
      reason: 'segment[$i].closed_at',
    );
  }

  // --- lifetime ---
  final expectedLifetime = expected['lifetime'] as Map<String, dynamic>;
  expect(lifetime.lPer100kmTenths, expectedLifetime['l_per_100km_tenths'],
      reason: 'lifetime.l_per_100km_tenths');
  expect(lifetime.totalDistanceM, expectedLifetime['total_distance_m'],
      reason: 'lifetime.total_distance_m');
  expect(lifetime.totalVolumeUL, expectedLifetime['total_volume_uL'],
      reason: 'lifetime.total_volume_uL');
  final expectedSpend = (expectedLifetime['total_spend_cents_by_currency']
          as Map)
      .cast<String, dynamic>();
  expect(lifetime.totalSpendCentsByCurrency.length, expectedSpend.length,
      reason: 'total_spend currency count');
  expectedSpend.forEach((currency, want) {
    expect(lifetime.totalSpendCentsByCurrency[currency], want,
        reason: 'total_spend[$currency]');
  });

  // --- price_history_by_currency ---
  final expectedPH =
      expected['price_history_by_currency'] as Map<String, dynamic>?;
  if (expectedPH != null) {
    final priceHistory = computePriceHistory(fillUps);
    expect(priceHistory.length, expectedPH.length,
        reason: 'price_history currency count');
    expectedPH.forEach((currency, wantListRaw) {
      final wantList = (wantListRaw as List).cast<Map<String, dynamic>>();
      final actualList = priceHistory[currency];
      expect(actualList, isNotNull,
          reason: 'price_history[$currency] missing');
      expect(actualList!.length, wantList.length,
          reason: 'price_history[$currency] count');
      for (var i = 0; i < wantList.length; i++) {
        final want = wantList[i];
        final actual = actualList[i];
        expect(actual.fillUpId, want['fillup_id'],
            reason: 'price_history[$currency][$i].fillup_id');
        expect(
          actual.filledAt,
          DateTime.parse(want['filled_at'] as String).toUtc(),
          reason: 'price_history[$currency][$i].filled_at',
        );
        expect(
          actual.centsPerLitreTenths,
          want['cents_per_litre_tenths'],
          reason: 'price_history[$currency][$i].cents_per_litre_tenths',
        );
      }
    });
  }

  // --- validation (non-rejection fixtures carry { rejected: false }) ---
  final expectedVal = expected['validation'] as Map<String, dynamic>?;
  if (expectedVal != null) {
    expect(expectedVal['rejected'], false,
        reason: 'segments fixture must not be a rejection');
  }
}

// ---------------------------------------------------------------------------
// Validation rejection
// ---------------------------------------------------------------------------

void _assertValidationRejection(
  Map<String, dynamic> input,
  Map<String, dynamic> expected,
) {
  final existingFillUps = (input['fillups'] as List)
      .map((raw) => _parseFillUp(raw as Map<String, dynamic>))
      .toList(growable: false);
  final candidate =
      _parseFillUp(input['candidate'] as Map<String, dynamic>);
  final nowUtc =
      DateTime.parse(input['now_utc'] as String).toUtc();

  final result = validateInsert(candidate, existingFillUps, nowUtc);

  final expectedVal = expected['validation'] as Map<String, dynamic>;
  expect(expectedVal['rejected'], true);
  expect(result, isNotNull, reason: 'expected rejection but got null');
  expect(result!.code.wire, expectedVal['error_code'],
      reason: 'error_code mismatch');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FillUp _parseFillUp(Map<String, dynamic> raw) {
  return FillUp(
    id: raw['id'] as String,
    vehicleId: raw['vehicle_id'] as String,
    filledAt: DateTime.parse(raw['filled_at'] as String).toUtc(),
    odometerM: raw['odometer_m'] as int,
    volumeUL: raw['volume_uL'] as int,
    totalPriceCents: raw['total_price_cents'] as int,
    currencyCode: raw['currency_code'] as String,
    isFull: raw['is_full'] as bool,
    missedBefore: (raw['missed_before'] as bool?) ?? false,
    odometerReset: (raw['odometer_reset'] as bool?) ?? false,
    notes: raw['notes'] as String?,
  );
}

String _statusToWire(SegmentStatus s) {
  switch (s) {
    case SegmentStatus.known:
      return 'known';
    case SegmentStatus.unknownMissed:
      return 'unknown_missed';
    case SegmentStatus.unknownResetBoundary:
      return 'unknown_reset_boundary';
    case SegmentStatus.degenerateZeroDistance:
      return 'degenerate_zero_distance';
  }
}

/// Resolve `tests/math/fixtures/` relative to the test file location.
/// `flutter test` runs with `Directory.current` set to the `client/`
/// package root, so we walk up one level to reach the repo root.
Directory _resolveFixturesDir() {
  final scriptPath = Platform.script.toFilePath();
  final candidates = <String>[
    '../tests/math/fixtures',
    'tests/math/fixtures',
    if (scriptPath.isNotEmpty)
      '${File(scriptPath).parent.path}/../../../tests/math/fixtures',
  ];
  for (final c in candidates) {
    final dir = Directory(c);
    if (dir.existsSync()) return dir.absolute;
  }
  return Directory(candidates.first).absolute;
}

String _basename(String path) {
  final idx = path.lastIndexOf('/');
  if (idx < 0) return path;
  return path.substring(idx + 1);
}
