import 'dart:io';
import 'dart:typed_data';

import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/export/assembler.dart';
import 'package:cestovni/export/headers.dart';
import 'package:cestovni/export/manifest.dart';
import 'package:cestovni/export/readme.dart';
import 'package:cestovni/export/store_zip_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '_zip.dart';

/// Spec item 12 / export A4: 1 000 fill-up rows is a CI-sized archive,
/// not a device-timing gate. Device 10k/30s stays on CES-68.
void main() {
  test('12 1000-row fill_ups ZIP imports without buffering as one table',
      () async {
    const vehicleId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final zip = _thousandFillUpsZip(vehicleId);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await importZip(dest, zip);

    expect(await dest.select(dest.fillUps).get(), hasLength(1000));
    expect(
      (await dest.select(dest.vehicles).get()).single.id,
      vehicleId,
    );
  });
}

Uint8List _thousandFillUpsZip(String vehicleId) {
  final dir = Directory.systemTemp.createTempSync('cestovni-import-stream-');
  final file = File('${dir.path}/thousand.zip');
  final sink = FileZipSink(file)
    ..stamp = DateTime.utc(2026, 8, 16, 12);
  assembleExportZip(
    sink: sink,
    manifestJson: encodeManifest(
      exportManifest(
        exportedAtUtc: '2026-08-16T12:00:00Z',
        appVersion: '0.0.1',
        appPlatform: 'android',
        timezone: 'UTC',
        userKeyHash: 'aabbccdd',
        preferredDistanceUnit: 'km',
        preferredVolumeUnit: 'L',
        currencyCode: 'EUR',
        vehiclesCount: 1,
        fillUpsCount: 1000,
        maintenanceRulesCount: 0,
        maintenanceEventsCount: 0,
        settingsCount: 1,
        outboxPendingCount: 0,
        outboxPendingHash: null,
      ),
    ),
    readmeText: buildReadmeExport(
      exportedAtUtc: '2026-08-16T12:00:00Z',
      preferredDistanceUnit: 'km',
      preferredVolumeUnit: 'L',
      currencyCode: 'EUR',
      timezone: 'UTC',
      outboxPendingCount: 0,
    ),
    tables: [
      ExportCsvTable(
        filename: 'vehicles.csv',
        header: vehiclesCsvHeader,
        rows: [
          [
            vehicleId,
            'aabbccdd',
            'Fleet',
            null,
            null,
            null,
            null,
            'gasoline',
            null,
            null,
            null,
            null,
            '2026-08-16T12:00:00.000Z',
          ],
        ],
      ),
      ExportCsvTable(
        filename: 'fill_ups.csv',
        header: fillUpsCsvHeader,
        rows: _lazyFillUps(vehicleId, 1000),
      ),
      const ExportCsvTable(
        filename: 'maintenance_rules.csv',
        header: maintenanceRulesCsvHeader,
        rows: [],
      ),
      const ExportCsvTable(
        filename: 'maintenance_events.csv',
        header: maintenanceEventsCsvHeader,
        rows: [],
      ),
      ExportCsvTable(
        filename: 'settings.csv',
        header: settingsCsvHeader,
        rows: [
          [
            'aabbccdd',
            'km',
            'L',
            'EUR',
            'UTC',
            vehicleId,
            null,
            '2026-08-16T12:00:00.000Z',
          ],
        ],
      ),
    ],
  );
  final bytes = file.readAsBytesSync();
  dir.deleteSync(recursive: true);
  return Uint8List.fromList(bytes);
}

Iterable<List<Object?>> _lazyFillUps(String vehicleId, int count) sync* {
  for (var i = 0; i < count; i++) {
    yield [
      '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      'aabbccdd',
      vehicleId,
      '2026-08-01T10:00:00.000Z',
      '2026-08-01 10:00:00',
      1000000 + i,
      '1',
      '1',
      40000000,
      '40.00',
      '10.57',
      5000,
      '50.00',
      'EUR',
      true,
      false,
      false,
      null,
      null,
      '2026-08-16T12:00:00.000Z',
    ];
  }
}
