/// Static guard: pure consumption-math files must not import Drift,
/// Flutter, or `package:cestovni/db/*`. Only `adapters.dart` is allowed
/// to bridge to Drift rows.
///
/// Spec: `docs/specs/consumption-math.md` + `client/lib/consumption/adapters.dart`
/// (Phase 2 of CES-38). Enforces the module purity invariant declared on
/// the adapter file so the math module can be reused server-side (M3) and
/// in tests without a Drift runtime.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final consumptionDir = _resolveConsumptionDir();

  test('consumption module directory is discoverable', () {
    expect(
      consumptionDir.existsSync(),
      isTrue,
      reason: 'client/lib/consumption/ must exist (looked at '
          '${consumptionDir.path}).',
    );
  });

  final dartFiles = consumptionDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // The set of forbidden import-prefix patterns. `adapters.dart` is the
  // ONLY file allowed to bridge to Drift / the app database.
  const forbiddenForPureFiles = <String>[
    'package:drift/',
    'package:flutter/',
    'package:cestovni/db/',
  ];

  test('every pure consumption file enforces the no-Drift / no-Flutter rule',
      () {
    final violations = <String>[];

    for (final file in dartFiles) {
      final basename = _basename(file.path);
      if (basename == 'adapters.dart') continue;

      final contents = file.readAsStringSync();
      for (final forbidden in forbiddenForPureFiles) {
        if (contents.contains("import '$forbidden") ||
            contents.contains('import "$forbidden')) {
          violations.add('$basename imports $forbidden');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Pure-Dart files in client/lib/consumption/ must not import '
          'Drift, Flutter, or the app DB. Violations:\n  - '
          '${violations.join("\n  - ")}',
    );
  });

  test('adapters.dart is the only file allowed to bridge to Drift', () {
    final adapter = File('${consumptionDir.path}/adapters.dart');
    expect(
      adapter.existsSync(),
      isTrue,
      reason: 'adapters.dart must exist as the documented Drift bridge.',
    );
    final body = adapter.readAsStringSync();
    expect(
      body.contains("package:cestovni/db/"),
      isTrue,
      reason: 'adapters.dart should bridge to package:cestovni/db/ — if this '
          'changes, update the purity invariant docstring.',
    );
  });
}

Directory _resolveConsumptionDir() {
  final candidates = <String>[
    'lib/consumption',
    'client/lib/consumption',
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
