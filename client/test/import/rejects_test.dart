import 'dart:typed_data';

import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/import/import_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '../export/_seed.dart';
import '_zip.dart';

void main() {
  late Uint8List golden;

  setUp(() async {
    final source = openInMemoryDb();
    await seedGoldenExport(source);
    golden = await exportDbToZip(source);
    await source.close();
  });

  Future<void> expectRejects(
    Uint8List bytes,
    ImportErrorCode code,
  ) async {
    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await expectImportRejected(dest, bytes, code: code);
  }

  test('3 header mutation → E_HEADER_MISMATCH, zero writes', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: -1, // header record
      column: 'odometer_m',
      value: 'odometer_meters',
    );
    await expectRejects(packZip(entries), ImportErrorCode.headerMismatch);
  });

  test('4 photo path in ZIP → E_PHOTOS_PRESENT', () async {
    final entries = unpackZip(golden);
    entries['photos/x.jpg'] = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00]);
    await expectRejects(packZip(entries), ImportErrorCode.photosPresent);
  });

  test('4 photos_in_export true → E_PHOTOS_PRESENT', () async {
    final entries = unpackZip(golden);
    entries['manifest.json'] = mutateManifest(
      entries['manifest.json']!,
      (m) => m['photos_in_export'] = true,
    );
    await expectRejects(packZip(entries), ImportErrorCode.photosPresent);
  });

  test('7 negative volume_uL → E_VALUE_INVALID', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: 0,
      column: 'volume_uL',
      value: '-1',
    );
    await expectRejects(packZip(entries), ImportErrorCode.valueInvalid);
  });

  test('7 1.0 in an INT column → E_VALUE_INVALID', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: 0,
      column: 'odometer_m',
      value: '1.0',
    );
    await expectRejects(packZip(entries), ImportErrorCode.valueInvalid);
  });

  test('7 bad currency_code → E_VALUE_INVALID', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: 0,
      column: 'currency_code',
      value: 'eu',
    );
    await expectRejects(packZip(entries), ImportErrorCode.valueInvalid);
  });

  test('7 unknown fuel_type → E_VALUE_INVALID', () async {
    final entries = unpackZip(golden);
    entries['vehicles.csv'] = mutateCsvCell(
      csv: entries['vehicles.csv']!,
      file: 'vehicles.csv',
      dataRow: 0,
      column: 'fuel_type',
      value: 'petrol',
    );
    await expectRejects(packZip(entries), ImportErrorCode.valueInvalid);
  });

  test('7 unknown category → E_VALUE_INVALID', () async {
    final entries = unpackZip(golden);
    entries['maintenance_events.csv'] = mutateCsvCell(
      csv: entries['maintenance_events.csv']!,
      file: 'maintenance_events.csv',
      dataRow: 0,
      column: 'category',
      value: 'wax',
    );
    await expectRejects(packZip(entries), ImportErrorCode.valueInvalid);
  });

  test('7 duplicate id → E_DUPLICATE_ID', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = duplicateCsvDataRow(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
    );
    entries['manifest.json'] = mutateManifest(
      entries['manifest.json']!,
      (m) {
        final counts = Map<String, dynamic>.from(m['row_counts'] as Map);
        counts['fill_ups'] = 2;
        m['row_counts'] = counts;
      },
    );
    await expectRejects(packZip(entries), ImportErrorCode.duplicateId);
  });

  test('7 missing cadence → E_CADENCE_MISSING', () async {
    final entries = unpackZip(golden);
    entries['maintenance_rules.csv'] = mutateCsvCell(
      csv: entries['maintenance_rules.csv']!,
      file: 'maintenance_rules.csv',
      dataRow: 0,
      column: 'cadence_km',
      value: '',
    );
    entries['maintenance_rules.csv'] = mutateCsvCell(
      csv: entries['maintenance_rules.csv']!,
      file: 'maintenance_rules.csv',
      dataRow: 0,
      column: 'cadence_days',
      value: '',
    );
    await expectRejects(packZip(entries), ImportErrorCode.cadenceMissing);
  });

  test('10 fill_ups.vehicle_id orphan → E_FK_ORPHAN', () async {
    final entries = unpackZip(golden);
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: 0,
      column: 'vehicle_id',
      value: '00000000-0000-4000-8000-000000000099',
    );
    await expectRejects(packZip(entries), ImportErrorCode.fkOrphan);
  });
}
