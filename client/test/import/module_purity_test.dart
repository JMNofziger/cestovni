/// Static guard on `client/lib/import/`: parser / validator / planner
/// stay pure Dart. Mirrors `client/test/export/module_purity_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _bridgeFiles = <String>{
  // Drift transaction + settings update + draft reconcile.
  'apply.dart',
  // Platform picker, dart:io inflater, photo-file cleanup.
  'import_service.dart',
};

const _forbiddenForPureFiles = <String>[
  'dart:io',
  'package:drift/',
  'package:flutter/',
  'package:file_picker/',
  'package:cestovni/db/',
];

void main() {
  final importDir = _resolveImportDir();

  test('import module directory is discoverable', () {
    expect(
      importDir.existsSync(),
      isTrue,
      reason: 'client/lib/import/ must exist (looked at ${importDir.path}).',
    );
  });

  final dartFiles = importDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('csv_parse, validate, plan, zip_read stay pure', () {
    final violations = <String>[];

    for (final file in dartFiles) {
      final basename = _basename(file.path);
      if (_bridgeFiles.contains(basename)) continue;

      final contents = file.readAsStringSync();
      for (final forbidden in _forbiddenForPureFiles) {
        if (contents.contains("import '$forbidden") ||
            contents.contains('import "$forbidden')) {
          violations.add('$basename imports $forbidden');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Pure files in client/lib/import/ must not import the file '
          'system, platform channels, Flutter, or the app DB. Violations:\n  - '
          '${violations.join("\n  - ")}',
    );
  });

  test('every declared bridge file exists', () {
    final present = dartFiles.map((f) => _basename(f.path)).toSet();
    expect(_bridgeFiles.difference(present), isEmpty);
  });
}

Directory _resolveImportDir() {
  for (final candidate in const ['lib/import', 'client/lib/import']) {
    final dir = Directory(candidate);
    if (dir.existsSync()) return dir.absolute;
  }
  return Directory('lib/import').absolute;
}

String _basename(String path) {
  final idx = path.lastIndexOf('/');
  return idx < 0 ? path : path.substring(idx + 1);
}
