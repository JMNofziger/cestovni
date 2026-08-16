import 'package:cestovni/export/assembler.dart';
import 'package:cestovni/export/headers.dart';
import 'package:cestovni/export/zip_sink.dart';
import 'package:cestovni/photos/photo_export_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assembler streams ~1000 fill-up rows as many small adds', () {
    final sink = CountingZipSink();
    assembleExportZip(
      sink: sink,
      manifestJson: '{"schema_version":1}\n',
      readmeText: 'Cestovni export\r\n',
      tables: [
        ExportCsvTable(
          filename: 'vehicles.csv',
          header: vehiclesCsvHeader,
          rows: const [],
        ),
        ExportCsvTable(
          filename: 'fill_ups.csv',
          header: fillUpsCsvHeader,
          rows: _lazyFillUps(1000),
        ),
        ExportCsvTable(
          filename: 'maintenance_rules.csv',
          header: maintenanceRulesCsvHeader,
          rows: const [],
        ),
        ExportCsvTable(
          filename: 'maintenance_events.csv',
          header: maintenanceEventsCsvHeader,
          rows: const [],
        ),
        ExportCsvTable(
          filename: 'settings.csv',
          header: settingsCsvHeader,
          rows: const [],
        ),
      ],
    );

    expect(sink.fileNames, exportZipEntryNames);
    expect(
      sink.addCalls,
      greaterThan(1000),
      reason: 'one add per CSV row plus BOM/header/other files — never a '
          'single concatenated table',
    );
    expect(
      sink.maxChunkBytes,
      lessThanOrEqualTo(512),
      reason: 'README slices at 512; a CSV row is smaller. A fully buffered '
          'table would be tens of KB in one add.',
    );
    expect(sink.maxChunkBytes, lessThan(sink.totalBytes));
    expect(
      sink.chunkSizes.where((n) => n == sink.totalBytes),
      isEmpty,
      reason: 'no single add may be the entire ZIP payload',
    );
  });

  test('assembler refuses a photos/ entry name', () {
    final sink = CountingZipSink();
    expect(
      () => assembleExportZip(
        sink: sink,
        manifestJson: '{}',
        readmeText: 'x\r\n',
        tables: [
          ExportCsvTable(
            filename: 'photos/receipt.jpg',
            header: 'id',
            rows: const [
              ['1'],
            ],
          ),
        ],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('assembled file list survives excludePhotoPaths unchanged', () {
    final sink = MemoryZipSink();
    assembleExportZip(
      sink: sink,
      manifestJson: '{}',
      readmeText: 'x\r\n',
      tables: [
        for (final name in [
          'vehicles.csv',
          'fill_ups.csv',
          'maintenance_rules.csv',
          'maintenance_events.csv',
          'settings.csv',
        ])
          ExportCsvTable(filename: name, header: 'id', rows: const []),
      ],
    );
    expect(excludePhotoPaths(sink.fileNames), sink.fileNames);
    expect(sink.fileNames.any(isPhotoSandboxPath), isFalse);
  });
}

Iterable<List<Object?>> _lazyFillUps(int count) sync* {
  for (var i = 0; i < count; i++) {
    yield <Object?>[
      'id-$i',
      'hashhash',
      'veh',
      '2026-08-01T10:30:00Z',
      '2026-08-01T10:30:00',
      1000 + i,
      '1',
      '1',
      1000,
      '0.00',
      '0.00',
      0,
      '0.00',
      'EUR',
      true,
      false,
      false,
      null,
      null,
      '2026-08-01T10:30:00Z',
    ];
  }
}
