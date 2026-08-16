/// Maps Drift rows → CSV field lists and runs the CES-41 assembler.
///
/// Drift / outbox / IO live here. The ZIP bytes themselves are produced
/// by the pure assembler + [ZipSink].
library;

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/repositories/outbox_repository.dart';
import '../db/repositories/settings_repository.dart';
import '../photos/photo_export_guard.dart';
import 'app_version.dart';
import 'assembler.dart';
import 'derived.dart';
import 'headers.dart';
import 'manifest.dart';
import 'readme.dart';
import 'timestamps.dart';
import 'user_key_hash.dart';
import 'zip_sink.dart';

class ExportSnapshot {
  ExportSnapshot({
    required this.settings,
    required this.vehicles,
    required this.fillUps,
    required this.maintenanceRules,
    required this.maintenanceEvents,
    required this.pendingMutationIds,
  });

  final SettingsRow settings;
  final List<VehicleRow> vehicles;
  final List<FillUpRow> fillUps;
  final List<MaintenanceRuleRow> maintenanceRules;
  final List<MaintenanceEventRow> maintenanceEvents;
  final List<String> pendingMutationIds;
}

/// Read-consistent snapshot of live rows (soft-deleted excluded).
///
/// Spec wants `BEGIN IMMEDIATE`; we use Drift's [AppDatabase.transaction]
/// instead of a raw `BEGIN` so we do not nest against Drift's executor.
/// Archived vehicles (`archived_at` set, `deleted_at` null) **are**
/// exported — they are still the user's history.
Future<ExportSnapshot> takeExportSnapshot(
  AppDatabase db, {
  OutboxRepository? outbox,
}) async {
  final box = outbox ?? OutboxRepository(db);
  return db.transaction(() async {
    final settings = await SettingsRepository(db).getOrBootstrap();
    final vehicles = await (db.select(db.vehicles)
          ..where((v) => v.deletedAt.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.id)]))
        .get();
    final fillUps = await (db.select(db.fillUps)
          ..where((f) => f.deletedAt.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.id)]))
        .get();
    final rules = await (db.select(db.maintenanceRules)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
    final events = await (db.select(db.maintenanceEvents)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.asc(e.id)]))
        .get();
    final pending = await box.pendingMutationIds();
    return ExportSnapshot(
      settings: settings,
      vehicles: vehicles,
      fillUps: fillUps,
      maintenanceRules: rules,
      maintenanceEvents: events,
      pendingMutationIds: pending,
    );
  });
}

void writeSnapshotToSink({
  required ZipSink sink,
  required ExportSnapshot snapshot,
  required String appVersion,
  required DateTime exportedAt,
  String appPlatform = kExportAppPlatform,
}) {
  final settings = snapshot.settings;
  final hash = userKeyHashFromSettingsId(settings.id);
  final tz = settings.timezone;
  final exportedAtUtc = formatExportedAt(exportedAt);
  final pending = snapshot.pendingMutationIds;
  final pendingCount = pending.length;
  final pendingHash = outboxPendingHash(pending);

  final manifest = exportManifest(
    exportedAtUtc: exportedAtUtc,
    appVersion: appVersion,
    appPlatform: appPlatform,
    timezone: tz,
    userKeyHash: hash,
    preferredDistanceUnit: settings.preferredDistanceUnit,
    preferredVolumeUnit: settings.preferredVolumeUnit,
    currencyCode: settings.currencyCode,
    vehiclesCount: snapshot.vehicles.length,
    fillUpsCount: snapshot.fillUps.length,
    maintenanceRulesCount: snapshot.maintenanceRules.length,
    settingsCount: 1,
    maintenanceEventsCount: snapshot.maintenanceEvents.length,
    outboxPendingCount: pendingCount,
    outboxPendingHash: pendingHash,
  );

  assembleExportZip(
    sink: sink,
    manifestJson: encodeManifest(manifest),
    readmeText: buildReadmeExport(
      exportedAtUtc: exportedAtUtc,
      preferredDistanceUnit: settings.preferredDistanceUnit,
      preferredVolumeUnit: settings.preferredVolumeUnit,
      currencyCode: settings.currencyCode,
      timezone: tz,
      outboxPendingCount: pendingCount,
    ),
    tables: [
      ExportCsvTable(
        filename: 'vehicles.csv',
        header: vehiclesCsvHeader,
        rows: snapshot.vehicles.map((v) => vehicleCsvRow(v, hash)),
      ),
      ExportCsvTable(
        filename: 'fill_ups.csv',
        header: fillUpsCsvHeader,
        rows: snapshot.fillUps.map((f) => fillUpCsvRow(f, hash, tz)),
      ),
      ExportCsvTable(
        filename: 'maintenance_rules.csv',
        header: maintenanceRulesCsvHeader,
        rows: snapshot.maintenanceRules.map((r) => ruleCsvRow(r, hash)),
      ),
      ExportCsvTable(
        filename: 'maintenance_events.csv',
        header: maintenanceEventsCsvHeader,
        rows: snapshot.maintenanceEvents.map((e) => eventCsvRow(e, hash, tz)),
      ),
      ExportCsvTable(
        filename: 'settings.csv',
        header: settingsCsvHeader,
        rows: [settingsCsvRow(settings, hash)],
      ),
    ],
  );

  final guarded = excludePhotoPaths(sink.fileNames);
  if (guarded.length != sink.fileNames.length) {
    throw StateError('photo path leaked into export file list');
  }
}

List<Object?> vehicleCsvRow(VehicleRow v, String hash) => [
      v.id,
      hash,
      v.name,
      v.make,
      v.model,
      v.year,
      v.vin,
      v.fuelType,
      v.tankCapacityUL,
      volumeToLitersCsv(v.tankCapacityUL),
      v.archivedAt == null ? null : formatUtcIso(v.archivedAt!),
      v.rowVersion, // null → empty (locked decision 6)
      formatUtcIso(v.updatedAt),
    ];

List<Object?> fillUpCsvRow(FillUpRow f, String hash, String tz) => [
      f.id,
      hash,
      f.vehicleId,
      formatUtcIso(f.filledAt),
      formatLocalIso(f.filledAt, tz),
      f.odometerM,
      metersToKmCsv(f.odometerM),
      metersToMiCsv(f.odometerM),
      f.volumeUL,
      volumeToLitersCsv(f.volumeUL),
      volumeToGallonsCsv(f.volumeUL),
      f.totalPriceCents,
      centsToMajorCsv(f.totalPriceCents),
      f.currencyCode,
      f.isFull,
      f.missedBefore,
      f.odometerReset,
      f.notes,
      f.rowVersion,
      formatUtcIso(f.updatedAt),
    ];

List<Object?> ruleCsvRow(MaintenanceRuleRow r, String hash) => [
      r.id,
      hash,
      r.vehicleId,
      r.name,
      r.cadenceKm, // meters, despite the name (A3)
      r.cadenceDays,
      r.enabled,
      r.notes,
      r.rowVersion,
      formatUtcIso(r.updatedAt),
    ];

List<Object?> eventCsvRow(
  MaintenanceEventRow e,
  String hash,
  String tz,
) =>
    [
      e.id,
      hash,
      e.vehicleId,
      e.ruleId,
      formatUtcIso(e.performedAt),
      formatLocalIso(e.performedAt, tz),
      e.odometerM,
      metersToKmCsv(e.odometerM),
      metersToMiCsv(e.odometerM),
      e.costCents,
      centsToMajorCsv(e.costCents),
      e.currencyCode,
      e.category,
      e.shop,
      e.notes,
      e.rowVersion,
      formatUtcIso(e.updatedAt),
    ];

List<Object?> settingsCsvRow(SettingsRow s, String hash) => [
      hash,
      s.preferredDistanceUnit,
      s.preferredVolumeUnit,
      s.currencyCode,
      s.timezone,
      s.defaultVehicleId,
      s.rowVersion,
      formatUtcIso(s.updatedAt),
    ];

String exportFilename({
  required String userKeyHash,
  required DateTime exportedAt,
}) =>
    'cestovni_export_${userKeyHash}_${formatFilenameTimestamp(exportedAt)}.zip';
