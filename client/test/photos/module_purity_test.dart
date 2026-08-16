/// Static guard on `client/lib/photos/`: the byte pipeline, the TTL rules and
/// the export guard must stay pure Dart, so the privacy behaviour can be
/// audited and tested without a camera, a sandbox, or a database.
///
/// Mirrors `test/consumption/module_purity_test.dart`. Three files are the
/// documented bridges to the impure world; everything else is pure.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to touch platform channels, the file system, or Drift.
const _bridgeFiles = <String>{
  // Sandbox file IO (`dart:io` + `path_provider`).
  'photo_store.dart',
  // Camera / library acquisition (platform channels via `image_picker`).
  'photo_picker.dart',
  // Lifecycle coordinator across `photo_refs`, files and the pure modules.
  'photo_service.dart',
};

const _forbiddenForPureFiles = <String>[
  'dart:io',
  'package:drift/',
  'package:flutter/',
  'package:path_provider/',
  'package:image_picker/',
  'package:cestovni/db/',
];

void main() {
  final photosDir = _resolvePhotosDir();

  test('photos module directory is discoverable', () {
    expect(
      photosDir.existsSync(),
      isTrue,
      reason: 'client/lib/photos/ must exist (looked at ${photosDir.path}).',
    );
  });

  final dartFiles = photosDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every pure photos file avoids platform, file-system and Drift imports',
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
      reason: 'Pure files in client/lib/photos/ must not import the file '
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

Directory _resolvePhotosDir() {
  for (final candidate in const ['lib/photos', 'client/lib/photos']) {
    final dir = Directory(candidate);
    if (dir.existsSync()) return dir.absolute;
  }
  return Directory('lib/photos').absolute;
}

String _basename(String path) {
  final idx = path.lastIndexOf('/');
  return idx < 0 ? path : path.substring(idx + 1);
}
