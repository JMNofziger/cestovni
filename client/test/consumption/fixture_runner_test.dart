/// Auto-discovery fixture runner for `tests/math/fixtures/*.json`.
///
/// Spec: `docs/specs/consumption-math.md` (CES-38).
///
/// Design:
/// - Discovers every `.json` file in `tests/math/fixtures/` at test time.
/// - Dispatches by `expected.kind`:
///     - `segments` → compute segments + lifetime, assert structural
///       equality against `expected.segments` / `expected.lifetime` /
///       (Phase 2) `expected.price_history_by_currency`.
///     - `validation_rejection` → (Phase 2) calls `validateInsert` and
///       asserts the typed error code matches.
///
/// Phase 1 scope: only fixture `01_normal_full_to_full.json` is asserted.
/// Every other fixture is marked skipped with a TODO pointing to Phase 2.
/// This gives us a green CI signal while the remaining math + validation
/// land incrementally.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cestovni/consumption/consumption.dart';
import 'package:cestovni/consumption/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures asserted by Phase 1. Every other fixture under
/// `tests/math/fixtures/` is auto-discovered and skipped with a TODO.
const _phase1Asserted = <String>{
  '01_normal_full_to_full.json',
};

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

    if (!_phase1Asserted.contains(basename)) {
      test('fixture $basename ($name)', () {
        // TODO(ces-38 phase 2): un-skip — requires full segment + partial
        // handling OR validation + price_history implementations.
      }, skip: 'phase 2 — not yet asserted');
      continue;
    }

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
      // TODO(ces-38 phase 2): wire up validateInsert once validation.dart
      // lands. Phase 1 uses only fixture #1 which is kind=segments.
      fail('validation_rejection dispatch not implemented in phase 1');
    default:
      fail('unknown expected.kind: $kind');
  }
}

void _assertSegmentsFixture(
  Map<String, dynamic> input,
  Map<String, dynamic> expected,
) {
  final fillUps = (input['fillups'] as List)
      .map((raw) => _parseFillUp(raw as Map<String, dynamic>))
      .toList(growable: false);

  final segments = computeSegments(fillUps);
  final lifetime = computeLifetime(segments, allFillUps: fillUps);

  final expectedSegments = (expected['segments'] as List).cast<Map<String, dynamic>>();
  expect(
    segments.length,
    expectedSegments.length,
    reason: 'segment count mismatch',
  );
  for (var i = 0; i < segments.length; i++) {
    final actual = segments[i];
    final want = expectedSegments[i];
    expect(actual.prevFullId, want['prev_full_id'], reason: 'segment[$i].prev_full_id');
    expect(actual.nextFullId, want['next_full_id'], reason: 'segment[$i].next_full_id');
    expect(_statusToWire(actual.status), want['status'], reason: 'segment[$i].status');
    expect(actual.distanceM, want['distance_m'], reason: 'segment[$i].distance_m');
    expect(actual.volumeUL, want['volume_uL'], reason: 'segment[$i].volume_uL');
    expect(actual.costCents, want['cost_cents'], reason: 'segment[$i].cost_cents');
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

  final expectedLifetime = expected['lifetime'] as Map<String, dynamic>;
  expect(lifetime.lPer100kmTenths, expectedLifetime['l_per_100km_tenths'],
      reason: 'lifetime.l_per_100km_tenths');
  expect(lifetime.totalDistanceM, expectedLifetime['total_distance_m'],
      reason: 'lifetime.total_distance_m');
  expect(lifetime.totalVolumeUL, expectedLifetime['total_volume_uL'],
      reason: 'lifetime.total_volume_uL');
  final expectedSpend =
      (expectedLifetime['total_spend_cents_by_currency'] as Map).cast<String, dynamic>();
  expect(lifetime.totalSpendCentsByCurrency.length, expectedSpend.length,
      reason: 'total_spend currency count');
  expectedSpend.forEach((currency, want) {
    expect(lifetime.totalSpendCentsByCurrency[currency], want,
        reason: 'total_spend[$currency]');
  });

  // TODO(ces-38 phase 2): assert price_history_by_currency once
  // price_history.dart lands.
}

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
  // When executed under `flutter test --no-pub`, Platform.script can be
  // the test file itself, a shim, or `data:`. Fall back to CWD-based
  // resolution which is stable in this repo layout.
  final candidates = <String>[
    // Relative to repo root from client/:
    '../tests/math/fixtures',
    // Relative to repo root from test runner CWD (some environments):
    'tests/math/fixtures',
    // Defensive: relative to the script file's dir.
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
