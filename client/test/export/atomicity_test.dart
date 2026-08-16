import 'dart:io';

import 'package:cestovni/export/export_service.dart';
import 'package:cestovni/export/store_zip_sink.dart';
import 'package:cestovni/export/zip_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '_seed.dart';

void main() {
  test('a mid-write failure leaves no .tmp and no final ZIP', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    await seedGoldenExport(db);

    final dir = Directory.systemTemp.createTempSync('cestovni-export-atom-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final service = ExportService(
      db: db,
      sandboxDir: () => dir,
      share: (_) async {},
      zipSink: (file) => _ThrowingSink(FileZipSink(file), throwAfterAdds: 6),
      clock: () => DateTime.utc(2026, 8, 16, 12, 0, 0),
    );

    await expectLater(service.exportToFile(), throwsA(isA<StateError>()));

    final leftovers = dir.listSync();
    expect(
      leftovers,
      isEmpty,
      reason: 'atomicity: neither the .tmp nor the final ZIP may remain. '
          'Found: $leftovers',
    );
  });
}

class _ThrowingSink implements ZipSink {
  _ThrowingSink(this._inner, {required this.throwAfterAdds});

  final ZipSink _inner;
  final int throwAfterAdds;
  int _adds = 0;

  @override
  void startFile(String name) => _inner.startFile(name);

  @override
  void add(List<int> bytes) {
    _inner.add(bytes);
    _adds++;
    if (_adds >= throwAfterAdds) {
      throw StateError('injected failure after $_adds adds');
    }
  }

  @override
  void closeFile() => _inner.closeFile();

  @override
  void close() => _inner.close();

  @override
  void abandon() => _inner.abandon();

  @override
  List<String> get fileNames => _inner.fileNames;
}
