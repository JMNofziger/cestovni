import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/export/app_version.dart';
import 'package:cestovni/export/csv.dart';
import 'package:cestovni/export/snapshot.dart';
import 'package:cestovni/export/store_zip_sink.dart';
import 'package:cestovni/import/csv_parse.dart';
import 'package:cestovni/import/import_errors.dart';
import 'package:cestovni/import/import_service.dart';
import 'package:cestovni/import/zip_read.dart';
import 'package:cestovni/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// STORE-ZIP a live database the same way CES-41 export does.
Future<Uint8List> exportDbToZip(AppDatabase db) async {
  final dir = Directory.systemTemp.createTempSync('cestovni-import-export-');
  final file = File('${dir.path}/export.zip');
  final sink = FileZipSink(file)
    ..stamp = DateTime.utc(2026, 8, 16, 12, 0, 0);
  writeSnapshotToSink(
    sink: sink,
    snapshot: await takeExportSnapshot(db),
    appVersion: kAppVersion,
    exportedAt: DateTime.utc(2026, 8, 16, 12, 0, 0),
  );
  sink.close();
  final bytes = file.readAsBytesSync();
  dir.deleteSync(recursive: true);
  return Uint8List.fromList(bytes);
}

/// Pack already-decoded ZIP entries back into a STORE ZIP.
Uint8List packZip(Map<String, Uint8List> entries) {
  final dir = Directory.systemTemp.createTempSync('cestovni-import-pack-');
  final file = File('${dir.path}/pack.zip');
  final sink = FileZipSink(file)
    ..stamp = DateTime.utc(2026, 8, 16, 12, 0, 0);
  for (final entry in entries.entries) {
    sink.startFile(entry.key);
    sink.add(entry.value);
    sink.closeFile();
  }
  sink.close();
  final bytes = file.readAsBytesSync();
  dir.deleteSync(recursive: true);
  return Uint8List.fromList(bytes);
}

Map<String, Uint8List> unpackZip(Uint8List bytes) => readZipEntries(bytes);

int csvColumn(String header, String name) {
  final index = header.split(',').indexOf(name);
  if (index < 0) {
    throw StateError('$name is not in $header');
  }
  return index;
}

/// Replace one data-row cell. [dataRow] is 0-based among data records
/// (header is row 0 of the file, skipped here).
Uint8List mutateCsvCell({
  required Uint8List csv,
  required String file,
  required int dataRow,
  required String column,
  required String value,
}) {
  final records = parseCsv(utf8.decode(csv), file: file);
  if (records.isEmpty) {
    throw StateError('$file has no header');
  }
  final header = records.first.fields.join(',');
  final col = csvColumn(header, column);
  final target = records[dataRow + 1];
  final fields = List<String>.from(target.fields);
  fields[col] = value;
  final rebuilt = <CsvRecord>[
    for (var i = 0; i < records.length; i++)
      i == dataRow + 1
          ? CsvRecord(fields: fields, line: target.line)
          : records[i],
  ];
  return _csvBytes(rebuilt);
}

Uint8List duplicateCsvDataRow({
  required Uint8List csv,
  required String file,
  int dataRow = 0,
}) {
  final records = parseCsv(utf8.decode(csv), file: file);
  final copy = records[dataRow + 1];
  return _csvBytes([...records, copy]);
}

Uint8List _csvBytes(List<CsvRecord> records) {
  final builder = BytesBuilder();
  builder.add(utf8Bom);
  for (final record in records) {
    builder.add(csvRowBytes(record.fields));
  }
  return builder.takeBytes();
}

Uint8List mutateManifest(
  Uint8List jsonBytes,
  void Function(Map<String, dynamic> manifest) edit,
) {
  final decoded = jsonDecode(utf8.decode(jsonBytes));
  if (decoded is! Map) {
    throw StateError('manifest.json is not an object');
  }
  final map = Map<String, dynamic>.from(decoded);
  edit(map);
  return Uint8List.fromList(utf8.encode(jsonEncode(map)));
}

Future<void> importZip(
  AppDatabase dest,
  Uint8List bytes, {
  String? confirmation,
  PhotoStore? photoStore,
}) async {
  final service = ImportService(db: dest, photoStore: photoStore);
  final preview = await service.preview(bytes);
  await service.commit(preview, typedConfirmation: confirmation);
}

Future<void> expectImportRejected(
  AppDatabase dest,
  Uint8List bytes, {
  required ImportErrorCode code,
  String? confirmation,
}) async {
  final before = await historyFingerprint(dest);
  final service = ImportService(db: dest);
  try {
    final preview = await service.preview(bytes);
    await service.commit(preview, typedConfirmation: confirmation);
    fail('expected ${code.wire}, import succeeded');
  } on ImportException catch (error) {
    expect(error.code, code, reason: error.display);
  }
  expect(
    await historyFingerprint(dest),
    before,
    reason: '${code.wire} must leave the database untouched',
  );
}

Future<String> historyFingerprint(AppDatabase db) async {
  final vehicles = (await db.select(db.vehicles).get())
    ..sort((a, b) => a.id.compareTo(b.id));
  final fills = (await db.select(db.fillUps).get())
    ..sort((a, b) => a.id.compareTo(b.id));
  final rules = (await db.select(db.maintenanceRules).get())
    ..sort((a, b) => a.id.compareTo(b.id));
  final events = (await db.select(db.maintenanceEvents).get())
    ..sort((a, b) => a.id.compareTo(b.id));
  final outbox = await db.select(db.outbox).get();
  return jsonEncode({
    'vehicles': [
      for (final row in vehicles)
        [row.id, row.name, row.fuelType, row.tankCapacityUL, row.updatedAt],
    ],
    'fill_ups': [
      for (final row in fills)
        [
          row.id,
          row.vehicleId,
          row.odometerM,
          row.volumeUL,
          row.totalPriceCents,
          row.notes,
          row.rowVersion,
        ],
    ],
    'rules': [
      for (final row in rules)
        [row.id, row.cadenceKm, row.cadenceDays, row.notes],
    ],
    'events': [
      for (final row in events) [row.id, row.category, row.shop, row.costCents],
    ],
    'outbox': outbox.length,
  });
}
