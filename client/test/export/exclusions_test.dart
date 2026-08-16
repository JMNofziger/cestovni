import 'dart:io';

import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/maintenance_events_repository.dart';
import 'package:cestovni/db/repositories/photo_refs_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/export/export_service.dart';
import 'package:cestovni/export/headers.dart';
import 'package:cestovni/export/snapshot.dart';
import 'package:cestovni/export/zip_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '_seed.dart';
import 'zip_read.dart';

void main() {
  test('soft-deleted rows and drafts are absent from the ZIP', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final seed = await seedGoldenExport(db);

    await FillUpsRepository(db).softDelete(seed.fillUpId);
    await MaintenanceEventsRepository(db).softDelete(seed.eventId);
    await VehiclesRepository(db).softDelete(seed.vehicleId);

    final liveId = await VehiclesRepository(db).create(
      const VehicleDraft(name: 'Live', fuelType: VehicleFuelType.diesel),
    );
    await DraftsRepository(db).save(
      DraftSnapshot(
        vehicleId: liveId,
        odometerM: 1,
        notes: 'should-not-export',
      ),
    );

    final snapshot = await takeExportSnapshot(db);
    expect(snapshot.vehicles.map((v) => v.id), [liveId]);
    expect(snapshot.fillUps, isEmpty);
    expect(snapshot.maintenanceEvents, isEmpty);

    final mem = MemoryZipSink();
    writeSnapshotToSink(
      sink: mem,
      snapshot: snapshot,
      appVersion: '0.0.1',
      exportedAt: DateTime.utc(2026, 8, 16),
    );
    expect(mem.utf8Of('fill_ups.csv'), isNot(contains(seed.fillUpId)));
    expect(mem.utf8Of('vehicles.csv'), isNot(contains('Octavia')));
    expect(mem.utf8Of('vehicles.csv'), contains('Live'));
    expect(mem.fileNames, isNot(contains('drafts.csv')));
    expect(mem.fileNames, isNot(contains('outbox.csv')));
    expect(mem.fileNames, isNot(contains('photo_refs.csv')));
    expect(mem.utf8Of('fill_ups.csv'), isNot(contains('should-not-export')));
  });

  test('archived vehicles are exported (not treated as deleted)', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final id = await VehiclesRepository(db).create(
      const VehicleDraft(name: 'Parked', fuelType: VehicleFuelType.gasoline),
    );
    await VehiclesRepository(db).archive(id);
    final snapshot = await takeExportSnapshot(db);
    expect(snapshot.vehicles.single.id, id);
    expect(snapshot.vehicles.single.archivedAt, isNotNull);
  });

  test('photo_refs and JPEG bytes never appear in the ZIP', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final vehicleId = await VehiclesRepository(db).create(
      const VehicleDraft(name: 'Daily', fuelType: VehicleFuelType.gasoline),
    );
    final draftId = await DraftsRepository(db).save(
      DraftSnapshot(vehicleId: vehicleId),
    );
    final sha = List.filled(64, 'a').join();
    await PhotoRefsRepository(db).insert(
      draftId: draftId,
      capturedAt: DateTime.utc(2026, 8, 1),
      byteSize: 12,
      sha256Hex: sha,
      ttlExpiresAt: DateTime.utc(2026, 8, 31),
    );

    final dir = Directory.systemTemp.createTempSync('cestovni-export-photos-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = await ExportService(
      db: db,
      sandboxDir: () => dir,
      share: (_) async {},
      clock: () => DateTime.utc(2026, 8, 16, 12, 0, 0),
    ).exportToFile();

    final entries = readStoreZip(file.readAsBytesSync());
    expect(entries.keys.toList(), exportZipEntryNames);
    expect(entries.keys.where((n) => n.contains('photos')), isEmpty);
    for (final bytes in entries.values) {
      expect(looksLikeJpeg(bytes), isFalse);
      expect(looksLikePng(bytes), isFalse);
    }
    final joined = entries.values.map(String.fromCharCodes).join();
    expect(joined, isNot(contains(sha)));
    expect(joined, isNot(contains(draftId)));
  });
}
