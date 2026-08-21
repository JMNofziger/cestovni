import 'dart:io';
import 'dart:typed_data';

import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/photo_refs_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/import/apply.dart';
import 'package:cestovni/import/import_errors.dart';
import 'package:cestovni/import/import_service.dart';
import 'package:cestovni/import/plan.dart';
import 'package:cestovni/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../db/_harness.dart';
import '../export/_seed.dart';
import '_zip.dart';

void main() {
  test('8 atomicity: failure while writing events rolls back prior history',
      () async {
    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await seedGoldenExport(dest);
    final before = await historyFingerprint(dest);

    try {
      await ImportApplier(dest).apply(_planThatFailsOnEvents());
      fail('expected E_TXN_FAILED');
    } on ImportException catch (error) {
      expect(error.code, ImportErrorCode.txnFailed);
    }

    expect(await historyFingerprint(dest), before);
    final names =
        (await dest.select(dest.vehicles).get()).map((v) => v.name).toSet();
    expect(names, contains('Octavia'));
    expect(names, isNot(contains('Incoming')));
  });

  test('13 replace clears prior history; disjoint ZIP wins', () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    final seed = await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    final localId = await VehiclesRepository(dest).create(
      const VehicleDraft(name: 'LocalOnly', fuelType: VehicleFuelType.diesel),
    );

    await importZip(dest, zip, confirmation: importConfirmationKeyword);

    final vehicles = await dest.select(dest.vehicles).get();
    expect(vehicles.map((v) => v.id).toSet(), {seed.vehicleId});
    expect(vehicles.single.name, 'Octavia');
    expect(vehicles.any((v) => v.id == localId), isFalse);
    expect(await dest.select(dest.fillUps).get(), hasLength(1));
  });

  test('14 settings updated in place; id unchanged; default vehicle validated',
      () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    final seed = await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    final original = await SettingsRepository(dest).update(
      preferredDistanceUnit: 'mi',
      preferredVolumeUnit: 'gal',
      currencyCode: 'USD',
      timezone: 'Europe/Prague',
    );

    await importZip(dest, zip);
    final adopted = await SettingsRepository(dest).getOrBootstrap();
    expect(adopted.id, original.id);
    expect(adopted.preferredDistanceUnit, 'km');
    expect(adopted.preferredVolumeUnit, 'L');
    expect(adopted.currencyCode, 'EUR');
    expect(adopted.timezone, 'UTC');
    expect(adopted.defaultVehicleId, seed.vehicleId);

    final dangling = unpackZip(zip);
    dangling['settings.csv'] = mutateCsvCell(
      csv: dangling['settings.csv']!,
      file: 'settings.csv',
      dataRow: 0,
      column: 'default_vehicle_id',
      value: '00000000-0000-4000-8000-000000000099',
    );
    await importZip(
      dest,
      packZip(dangling),
      confirmation: importConfirmationKeyword,
    );
    final cleared = await SettingsRepository(dest).getOrBootstrap();
    expect(cleared.id, original.id);
    expect(cleared.defaultVehicleId, isNull);
  });

  test('15 outbox is cleared and the discarded count is reported', () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    final vehicleId = await VehiclesRepository(dest).create(
      const VehicleDraft(name: 'Queued', fuelType: VehicleFuelType.gasoline),
    );
    await FillUpsRepository(dest).create(
      FillUpDraft(
        vehicleId: vehicleId,
        filledAt: DateTime.utc(2026, 8, 2, 9),
        odometerM: 1000,
        volumeUL: 10000000,
        totalPriceCents: 100,
        currencyCode: 'EUR',
        isFull: true,
      ),
    );
    expect(await OutboxRepository(dest).pendingMutationIds(), isNotEmpty);
    final pending = (await OutboxRepository(dest).pendingMutationIds()).length;

    final service = ImportService(db: dest);
    final preview = await service.preview(zip);
    expect(preview.footprint.queuedChanges, pending);
    final outcome = await service.commit(
      preview,
      typedConfirmation: importConfirmationKeyword,
    );

    expect(outcome.queueDiscarded, pending);
    expect(await dest.select(dest.outbox).get(), isEmpty);
  });

  test('16 drafts: surviving vehicle keeps draft+photo; destroyed purges both',
      () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await importZip(dest, zip);

    final keptVehicle =
        (await dest.select(dest.vehicles).get()).single.id;
    final keptDraftId = await DraftsRepository(dest).save(
      DraftSnapshot(vehicleId: keptVehicle, notes: 'keep me'),
    );
    final doomedVehicle = await VehiclesRepository(dest).create(
      const VehicleDraft(name: 'Doomed', fuelType: VehicleFuelType.diesel),
    );
    final doomedDraftId = await DraftsRepository(dest).save(
      DraftSnapshot(vehicleId: doomedVehicle, notes: 'drop me'),
    );

    final sandbox = Directory.systemTemp.createTempSync('cestovni-import-photos-');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });
    final store = PhotoStore.inDirectory(Directory(p.join(sandbox.path, 'photos')));
    const jpeg = [0xFF, 0xD8, 0xFF, 0xD9];
    final keptPhoto = await PhotoRefsRepository(dest).insert(
      draftId: keptDraftId,
      capturedAt: DateTime.utc(2026, 8, 16),
      byteSize: jpeg.length,
      sha256Hex: 'aa' * 32,
      ttlExpiresAt: DateTime.utc(2026, 9, 16),
    );
    final doomedPhoto = await PhotoRefsRepository(dest).insert(
      draftId: doomedDraftId,
      capturedAt: DateTime.utc(2026, 8, 16),
      byteSize: jpeg.length,
      sha256Hex: 'bb' * 32,
      ttlExpiresAt: DateTime.utc(2026, 9, 16),
    );
    await store.write(keptPhoto.id, Uint8List.fromList(jpeg));
    await store.write(doomedPhoto.id, Uint8List.fromList(jpeg));

    final service = ImportService(db: dest, photoStore: store);
    final preview = await service.preview(zip);
    expect(preview.footprint.draftsAtRisk, 1);
    final outcome = await service.commit(
      preview,
      typedConfirmation: importConfirmationKeyword,
    );

    expect(outcome.draftsDiscarded, 1);
    expect(outcome.photoIdsToDelete, [doomedPhoto.id]);
    expect(
      await DraftsRepository(dest).openDraftForVehicle(keptVehicle),
      isNotNull,
    );
    expect(
      await DraftsRepository(dest).openDraftForVehicle(doomedVehicle),
      isNull,
    );
    expect(
      await PhotoRefsRepository(dest).findById(keptPhoto.id),
      isNotNull,
    );
    expect(
      await PhotoRefsRepository(dest).findById(doomedPhoto.id),
      isNull,
    );
    expect(await store.exists(keptPhoto.id), isTrue);
    expect(await store.exists(doomedPhoto.id), isFalse);
    expect(
      (await dest.select(dest.vehicles).get()).map((v) => v.name),
      ['Octavia'],
    );
  });

  test('17 confirmation: keyword required iff local history is non-empty',
      () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final empty = openInMemoryDb();
    addTearDown(empty.close);
    await SettingsRepository(empty).getOrBootstrap();
    final emptyService = ImportService(db: empty);
    final emptyPreview = await emptyService.preview(zip);
    expect(emptyPreview.requiresTypedConfirmation, isFalse);
    await emptyService.commit(emptyPreview);
    expect(await empty.select(empty.vehicles).get(), hasLength(1));

    final populated = openInMemoryDb();
    addTearDown(populated.close);
    await seedGoldenExport(populated);
    await expectImportRejected(
      populated,
      zip,
      code: ImportErrorCode.notConfirmed,
    );
    await importZip(
      populated,
      zip,
      confirmation: importConfirmationKeyword,
    );
    expect(await populated.select(populated.vehicles).get(), hasLength(1));
  });
}

ImportPlan _planThatFailsOnEvents() {
  const incomingVehicle = '11111111-1111-4111-8111-111111111111';
  const missingVehicle = '33333333-3333-4333-8333-333333333333';
  return ImportPlan(
    manifest: const ImportedManifest(
      schemaVersion: 1,
      exportedAtUtc: '2026-08-16T12:00:00Z',
      appVersion: '0.0.1',
      appPlatform: 'android',
      timezone: 'UTC',
      userKeyHash: 'deadbeef',
      outboxPendingCount: 0,
      rowCounts: {
        'vehicles': 1,
        'fill_ups': 0,
        'maintenance_rules': 0,
        'maintenance_events': 1,
        'settings': 1,
      },
    ),
    vehicles: const [
      ImportedVehicle(
        id: incomingVehicle,
        name: 'Incoming',
        fuelType: 'gasoline',
        updatedAt: '2026-08-16T12:00:00.000Z',
      ),
    ],
    fillUps: const [],
    maintenanceRules: const [],
    maintenanceEvents: const [
      ImportedMaintenanceEvent(
        id: '22222222-2222-4222-8222-222222222222',
        vehicleId: missingVehicle,
        performedAt: '2026-08-16T12:00:00.000Z',
        costCents: 0,
        currencyCode: 'EUR',
        category: 'oil',
        updatedAt: '2026-08-16T12:00:00.000Z',
      ),
    ],
    settings: const ImportedSettings(
      preferredDistanceUnit: 'km',
      preferredVolumeUnit: 'L',
      currencyCode: 'EUR',
      timezone: 'UTC',
      updatedAt: '2026-08-16T12:00:00.000Z',
    ),
    warnings: const [],
  );
}
