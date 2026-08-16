/// Streams export tables into a [ZipSink] (CES-41).
///
/// Pure of Flutter / `dart:io`. Takes already-filtered iterables so a
/// 1 000-row fill-up fixture can be a lazy generator. Each CSV row is
/// a separate [ZipSink.add] — that is the streaming invariant tests
/// assert.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../photos/photo_export_guard.dart';
import 'csv.dart';
import 'zip_sink.dart';

class ExportCsvTable {
  const ExportCsvTable({
    required this.filename,
    required this.header,
    required this.rows,
  });

  final String filename;
  final String header;

  /// Lazy. One list of fields per row, matching [header] order.
  final Iterable<List<Object?>> rows;
}

/// Write [tables] plus [manifestJson] and [readmeText] into [sink].
///
/// Throws [StateError] if any entry name is inside the photo sandbox
/// (the assembler must never put `photos/` in the ZIP).
void assembleExportZip({
  required ZipSink sink,
  required String manifestJson,
  required String readmeText,
  required List<ExportCsvTable> tables,
}) {
  final written = <String>[];

  void writeTextFile(String name, String text, {bool crlfAlready = false}) {
    _start(sink, name, written);
    final String body = crlfAlready ? text : text.replaceAll('\n', crlf);
    // Chunk the body so a large README still does not land as one
    // giant add — 512-byte slices are enough for the streaming test.
    final Uint8List bytes = Uint8List.fromList(utf8.encode(body));
    _addInSlices(sink, bytes);
    sink.closeFile();
  }

  writeTextFile('manifest.json', manifestJson);
  writeTextFile('README_export.txt', readmeText, crlfAlready: true);

  for (final table in tables) {
    _start(sink, table.filename, written);
    sink.add(utf8Bom);
    sink.add(csvHeaderBytes(table.header));
    for (final row in table.rows) {
      sink.add(csvRowBytes(row));
    }
    sink.closeFile();
  }

  sink.close();

  final allowed = excludePhotoPaths(written);
  if (allowed.length != written.length) {
    throw StateError(
      'export assembler attempted to write a photo-sandbox path: $written',
    );
  }
}

void _start(ZipSink sink, String name, List<String> written) {
  if (isPhotoSandboxPath(name)) {
    throw StateError('refusing to add photo path $name to export ZIP');
  }
  sink.startFile(name);
  written.add(name);
}

void _addInSlices(ZipSink sink, Uint8List bytes) {
  const int slice = 512;
  if (bytes.length <= slice) {
    sink.add(bytes);
    return;
  }
  for (var i = 0; i < bytes.length; i += slice) {
    final end = i + slice > bytes.length ? bytes.length : i + slice;
    sink.add(bytes.sublist(i, end));
  }
}
