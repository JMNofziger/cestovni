/// Static guard on `client/lib/export/`: CSV / ZIP assembly stay pure
/// Dart so streaming behaviour can be tested without Flutter, Drift, or
/// a sandbox. Mirrors `test/photos/module_purity_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to touch the file system, Drift, Flutter, or share.
const _bridgeFiles = <String>{
  // STORE ZIP writer (`dart:io` RandomAccessFile).
  'store_zip_sink.dart',
  // Drift snapshot + CSV row mapping.
  'snapshot.dart',
  // Flush + atomic rename + share_plus / path_provider.
  'export_service.dart',
};

const _forbiddenForPureFiles = <String>[
  'dart:io',
  'package:drift/',
  'package:flutter/',
  'package:path_provider/',
  'package:share_plus/',
  'package:cestovni/db/',
];

void main() {
  final exportDir = _resolveExportDir();

  test('export module directory is discoverable', () {
    expect(
      exportDir.existsSync(),
      isTrue,
      reason: 'client/lib/export/ must exist (looked at ${exportDir.path}).',
    );
  });

  final dartFiles = exportDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every pure export file avoids platform, file-system and Drift imports',
      () {
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
      reason: 'Pure files in client/lib/export/ must not import the file '
          'system, platform channels, Flutter, or the app DB. Add the file to '
          '_bridgeFiles only with a documented reason. Violations:\n  - '
          '${violations.join("\n  - ")}',
    );
  });

  test('every declared bridge file exists', () {
    final present = dartFiles.map((f) => _basename(f.path)).toSet();

    expect(
      _bridgeFiles.difference(present),
      isEmpty,
      reason: 'a file listed in _bridgeFiles was renamed or removed — update '
          'the purity invariant with it',
    );
  });
}

Directory _resolveExportDir() {
  for (final candidate in const ['lib/export', 'client/lib/export']) {
    final dir = Directory(candidate);
    if (dir.existsSync()) return dir.absolute;
  }
  return Directory('lib/export').absolute;
}

String _basename(String path) {
  final idx = path.lastIndexOf('/');
  return idx < 0 ? path : path.substring(idx + 1);
}
