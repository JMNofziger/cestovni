import 'dart:convert';
import 'dart:io';

import 'package:cestovni/export/app_version.dart';
import 'package:cestovni/export/derived.dart';
import 'package:cestovni/export/export_service.dart';
import 'package:cestovni/export/headers.dart';
import 'package:cestovni/export/snapshot.dart';
import 'package:cestovni/export/user_key_hash.dart';
import 'package:cestovni/export/zip_sink.dart';
import 'package:cestovni/photos/photo_export_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '_seed.dart';
import 'zip_read.dart';

void main() {
  test('golden snapshot: headers, cells, manifest stand-ins', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final seed = await seedGoldenExport(db);
    final snapshot = await takeExportSnapshot(db);
    final hash = userKeyHashFromSettingsId(seed.settings.id);

    final mem = MemoryZipSink();
    final exportedAt = DateTime.utc(2026, 8, 16, 12, 0, 0);
    writeSnapshotToSink(
      sink: mem,
      snapshot: snapshot,
      appVersion: kAppVersion,
      exportedAt: exportedAt,
    );

    expect(mem.fileNames, exportZipEntryNames);

    final vehicles = csvRecords(mem.bytesOf('vehicles.csv'));
    expect(vehicles.first, vehiclesCsvHeader);
    final v = parseCsvRecord(vehicles[1]);
    expect(v[0], seed.vehicleId);
    expect(v[1], hash);
    expect(v[2], 'Octavia');
    expect(v[8], '55000000');
    expect(v[9], '55.00');
    expect(v[11], '', reason: 'row_version is empty until M3');

    final fills = csvRecords(mem.bytesOf('fill_ups.csv'));
    expect(fills.first, fillUpsCsvHeader);
    final f = parseCsvRecord(fills[1]);
    expect(f[0], seed.fillUpId);
    expect(f[5], '120000000');
    expect(f[6], metersToKmCsv(120000000));
    expect(f[7], metersToMiCsv(120000000));
    expect(f[8], '42000000');
    expect(f[9], volumeToLitersCsv(42000000));
    expect(f[10], volumeToGallonsCsv(42000000));
    expect(f[11], '6100');
    expect(f[12], centsToMajorCsv(6100));
    expect(f[14], 'true');
    expect(f[17], 'hello, "world"');
    expect(f[18], '');

    final rules = csvRecords(mem.bytesOf('maintenance_rules.csv'));
    expect(rules.first, maintenanceRulesCsvHeader);
    final r = parseCsvRecord(rules[1]);
    expect(r[0], seed.ruleId);
    expect(r[4], '10000000', reason: 'cadence_km is meters, exported verbatim');
    expect(r[6], 'true');
    expect(r[7], 'every 10k km');

    final events = csvRecords(mem.bytesOf('maintenance_events.csv'));
    expect(events.first, maintenanceEventsCsvHeader);
    final e = parseCsvRecord(events[1]);
    expect(e[0], seed.eventId);
    expect(e[12], 'oil');
    expect(e[13], 'Bosch, Praha');

    final settingsLines = csvRecords(mem.bytesOf('settings.csv'));
    expect(settingsLines.first, settingsCsvHeader);
    final s = parseCsvRecord(settingsLines[1]);
    expect(s[0], hash);
    expect(s[4], 'UTC');
    expect(s[5], seed.vehicleId);

    final manifest = jsonDecode(mem.utf8Of('manifest.json')) as Map<String, dynamic>;
    expect(manifest['photos_in_export'], photosInExport);
    expect(manifest['photos_in_export'], isFalse);
    expect(manifest['max_row_version_seen'], isNull);
    expect(manifest['app_platform'], kExportAppPlatform);
    expect(manifest['app_version'], kAppVersion);
    expect(manifest['user_key_hash'], hash);
    expect(manifest['row_counts']['vehicles'], 1);
    expect(manifest['row_counts']['fill_ups'], 1);
    expect(manifest['row_counts']['maintenance_rules'], 1);
    expect(manifest['row_counts']['maintenance_events'], 1);
    expect(manifest['row_counts']['settings'], 1);

    final readme = mem.utf8Of('README_export.txt');
    expect(readme, contains('cadence_km stores canonical METERS'));
    expect(readme, contains('first 8 hex characters of SHA-256'));
    expect(readme.contains('\r\n'), isTrue);

    final name = exportFilename(userKeyHash: hash, exportedAt: exportedAt);
    expect(
      name,
      matches(RegExp(r'^cestovni_export_[0-9a-f]{8}_20260816_120000\.zip$')),
    );
    expect(name, 'cestovni_export_${hash}_20260816_120000.zip');
  });

  test('ExportService writes a valid STORE ZIP on disk', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    await seedGoldenExport(db);

    final dir = Directory.systemTemp.createTempSync('cestovni-export-golden-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final shared = <String>[];
    final service = ExportService(
      db: db,
      sandboxDir: () => dir,
      share: (path) async => shared.add(path),
      clock: () => DateTime.utc(2026, 8, 16, 12, 0, 0),
    );
    final file = await service.exportAndShare();
    expect(file.existsSync(), isTrue);
    expect(file.path, isNot(contains('.tmp')));
    expect(
      file.uri.pathSegments.last,
      matches(RegExp(r'^cestovni_export_[0-9a-f]{8}_20260816_120000\.zip$')),
    );
    expect(shared, [file.path]);

    final entries = readStoreZip(file.readAsBytesSync());
    expect(entries.keys.toList(), exportZipEntryNames);
    for (final bytes in entries.values) {
      expect(looksLikeJpeg(bytes), isFalse);
      expect(looksLikePng(bytes), isFalse);
    }
    expect(entries.keys.any((n) => n.contains('photos')), isFalse);
  });
}
