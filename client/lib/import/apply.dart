/// Applies a validated [ImportPlan] with **replace** semantics (CES-70).
///
/// Spec: `docs/specs/export-import.md` § Replace semantics. Mode is
/// `replace` and merge is not built — see that spec's § Product
/// decisions for why (export omits tombstones, so a merge could never
/// delete anything).
///
/// Everything here runs inside one Drift transaction, so any failure
/// leaves the database byte-identical. The single deliberate exception is
/// photo **file** deletion, which the caller performs *after* commit;
/// see [ImportOutcome.photoIdsToDelete].
library;

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/repositories/protocol_writes.dart';
import 'import_errors.dart';
import 'plan.dart';

/// What an import removed and wrote. Drives the post-import summary.
class ImportOutcome {
  const ImportOutcome({
    required this.rowsWritten,
    required this.rowsReplaced,
    required this.queueDiscarded,
    required this.draftsDiscarded,
    required this.photoIdsToDelete,
    required this.defaultVehicleAdopted,
  });

  /// Rows inserted per table (plus `settings: 1`, updated in place).
  final Map<String, int> rowsWritten;

  /// Rows destroyed per table.
  final Map<String, int> rowsReplaced;

  /// Pending outbox entries cleared.
  final int queueDiscarded;

  /// Drafts removed because their vehicle is not in the archive.
  final int draftsDiscarded;

  /// `photo_refs.id`s whose rows were deleted; their JPEGs must be
  /// removed **after** the transaction commits.
  final List<String> photoIdsToDelete;

  /// Whether `settings.default_vehicle_id` from the archive survived
  /// validation against the imported vehicles.
  final bool defaultVehicleAdopted;

  int get totalWritten =>
      rowsWritten.values.fold(0, (sum, value) => sum + value);

  int get totalReplaced =>
      rowsReplaced.values.fold(0, (sum, value) => sum + value);
}

/// Counts of what a replace would destroy, for the confirm dialog.
class LocalFootprint {
  const LocalFootprint({
    required this.rowCounts,
    required this.queuedChanges,
    required this.draftsAtRisk,
  });

  final Map<String, int> rowCounts;
  final int queuedChanges;

  /// Drafts that would be discarded — computed against the archive's
  /// vehicle ids, so this is only meaningful for a specific plan.
  final int draftsAtRisk;

  int get totalRows => rowCounts.values.fold(0, (sum, value) => sum + value);

  /// Whether there is any history to lose. Drives whether the typed
  /// confirmation is required at all.
  bool get isEmpty => totalRows == 0;
}

class ImportApplier {
  ImportApplier(
    this.db, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final AppDatabase db;
  final String Function() _newId;

  /// What replace would destroy, measured against [plan].
  ///
  /// Counts every row including soft-deleted ones: a hard `DELETE` takes
  /// those too, and the user is entitled to know.
  Future<LocalFootprint> measure(ImportPlan plan) async {
    final counts = <String, int>{
      'vehicles': await _countAll(db.vehicles),
      'fill_ups': await _countAll(db.fillUps),
      'maintenance_rules': await _countAll(db.maintenanceRules),
      'maintenance_events': await _countAll(db.maintenanceEvents),
    };
    final queued = await _countAll(db.outbox);
    final doomed = await _draftsWithoutVehicle(plan.vehicleIds);
    return LocalFootprint(
      rowCounts: counts,
      queuedChanges: queued,
      draftsAtRisk: doomed.length,
    );
  }

  /// Replace local history with [plan].
  ///
  /// Ordering (spec § Replace semantics → Ordering):
  /// 1. delete children before parents,
  /// 2. clear the outbox,
  /// 3. insert parents before children,
  /// 4. update `settings` in place — never delete it, or `settings.id`
  ///    (the local identity) would be destroyed,
  /// 5. reconcile drafts against the imported vehicles.
  Future<ImportOutcome> apply(ImportPlan plan) async {
    try {
      return await db.transaction(() async {
        final replaced = <String, int>{
          'maintenance_events': await db.delete(db.maintenanceEvents).go(),
          'fill_ups': await db.delete(db.fillUps).go(),
          'maintenance_rules': await db.delete(db.maintenanceRules).go(),
          'vehicles': await db.delete(db.vehicles).go(),
        };

        // Every outbox row describes a mutation on one of the four tables
        // just cleared (the `table` CHECK admits nothing else), so
        // keeping them would later push rows the user replaced.
        final queueDiscarded = await db.delete(db.outbox).go();

        await _insertVehicles(plan.vehicles);
        await _insertRules(plan.maintenanceRules);
        await _insertFillUps(plan.fillUps);
        await _insertEvents(plan.maintenanceEvents);

        final adopted = await _updateSettings(plan);

        final reconciled = await _reconcileDrafts(plan.vehicleIds);

        return ImportOutcome(
          rowsWritten: <String, int>{
            'vehicles': plan.vehicles.length,
            'fill_ups': plan.fillUps.length,
            'maintenance_rules': plan.maintenanceRules.length,
            'maintenance_events': plan.maintenanceEvents.length,
            'settings': 1,
          },
          rowsReplaced: replaced,
          queueDiscarded: queueDiscarded,
          draftsDiscarded: reconciled.draftsDeleted,
          photoIdsToDelete: reconciled.photoIds,
          defaultVehicleAdopted: adopted,
        );
      });
    } on ImportException {
      rethrow;
    } catch (error) {
      throw ImportException(
        ImportErrorCode.txnFailed,
        'The import could not be applied, so nothing was changed: $error',
      );
    }
  }

  // ───────────────────────────────────────── inserts

  /// Imported rows are **never-synced**: `user_id` and `row_version` stay
  /// null (the server assigns them on first write), `deleted_at` is null
  /// because soft-deleted rows never leave in an export, `updated_at` is
  /// preserved from the archive, and `mutation_id` is freshly generated
  /// because it is local bookkeeping the archive does not carry.
  Future<void> _insertVehicles(List<ImportedVehicle> rows) async {
    await db.batch((batch) {
      for (final row in rows) {
        batch.insert(
          db.vehicles,
          VehiclesCompanion.insert(
            id: row.id,
            userId: const Value(null),
            rowVersion: const Value(null),
            updatedAt: row.updatedAt,
            deletedAt: const Value(null),
            mutationId: _newId(),
            name: row.name,
            make: Value(row.make),
            model: Value(row.model),
            year: Value(row.year),
            vin: Value(row.vin),
            fuelType: row.fuelType,
            tankCapacityUL: Value(row.tankCapacityUL),
            archivedAt: Value(row.archivedAt),
          ),
        );
      }
    });
  }

  Future<void> _insertRules(List<ImportedMaintenanceRule> rows) async {
    await db.batch((batch) {
      for (final row in rows) {
        batch.insert(
          db.maintenanceRules,
          MaintenanceRulesCompanion.insert(
            id: row.id,
            userId: const Value(null),
            rowVersion: const Value(null),
            updatedAt: row.updatedAt,
            deletedAt: const Value(null),
            mutationId: _newId(),
            vehicleId: row.vehicleId,
            name: row.name,
            // Canonical meters, verbatim. The column is still named
            // `cadence_km` until CES-71 renames it.
            cadenceKm: Value(row.cadenceMeters),
            cadenceDays: Value(row.cadenceDays),
            enabled: Value(row.enabled),
            notes: Value(row.notes),
          ),
        );
      }
    });
  }

  Future<void> _insertFillUps(List<ImportedFillUp> rows) async {
    await db.batch((batch) {
      for (final row in rows) {
        batch.insert(
          db.fillUps,
          FillUpsCompanion.insert(
            id: row.id,
            userId: const Value(null),
            rowVersion: const Value(null),
            updatedAt: row.updatedAt,
            deletedAt: const Value(null),
            mutationId: _newId(),
            vehicleId: row.vehicleId,
            filledAt: row.filledAt,
            odometerM: row.odometerM,
            volumeUL: row.volumeUL,
            totalPriceCents: row.totalPriceCents,
            currencyCode: row.currencyCode,
            isFull: row.isFull,
            missedBefore: Value(row.missedBefore),
            odometerReset: Value(row.odometerReset),
            notes: Value(row.notes),
          ),
        );
      }
    });
  }

  Future<void> _insertEvents(List<ImportedMaintenanceEvent> rows) async {
    await db.batch((batch) {
      for (final row in rows) {
        batch.insert(
          db.maintenanceEvents,
          MaintenanceEventsCompanion.insert(
            id: row.id,
            userId: const Value(null),
            rowVersion: const Value(null),
            updatedAt: row.updatedAt,
            deletedAt: const Value(null),
            mutationId: _newId(),
            vehicleId: row.vehicleId,
            ruleId: Value(row.ruleId),
            performedAt: row.performedAt,
            odometerM: Value(row.odometerM),
            // `cost_cents` and `category` carry SQL defaults (0 and
            // 'other'), so Drift models them as optional on insert.
            costCents: Value(row.costCents),
            currencyCode: row.currencyCode,
            category: Value(row.category),
            shop: Value(row.shop),
            notes: Value(row.notes),
          ),
        );
      }
    });
  }

  // ───────────────────────────────────────── settings

  /// Adopt the archive's display preferences, leaving identity alone.
  ///
  /// `settings` is updated, never deleted and re-inserted: the row's `id`
  /// **is** the local user id, and the archive deliberately omits it
  /// (`export-v1.md` § A1). `row_version` and `user_id` are likewise
  /// untouched.
  Future<bool> _updateSettings(ImportPlan plan) async {
    final existing = await db.select(db.appSettings).getSingleOrNull();
    final incoming = plan.settings;

    // Only honour a default vehicle that actually arrived; CES-57
    // re-validates against live vehicles anyway, but persisting a
    // dangling id here would be storing known-bad data.
    final requested = incoming.defaultVehicleId;
    final adopted = requested != null && plan.vehicleIds.contains(requested);

    if (existing == null) {
      // A fresh install that has not booted the Settings bootstrap yet.
      // Generate the local identity here rather than taking one from the
      // archive, which does not carry it.
      final id = _newId();
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              id: id,
              userId: const Value(null),
              rowVersion: const Value(null),
              updatedAt: incoming.updatedAt,
              deletedAt: const Value(null),
              mutationId: _newId(),
              preferredDistanceUnit: incoming.preferredDistanceUnit,
              preferredVolumeUnit: incoming.preferredVolumeUnit,
              currencyCode: incoming.currencyCode,
              timezone: incoming.timezone,
              defaultVehicleId: Value(adopted ? requested : null),
            ),
          );
      return adopted;
    }

    await (db.update(db.appSettings)
          ..where((s) => s.id.equals(existing.id)))
        .write(
      AppSettingsCompanion(
        preferredDistanceUnit: Value(incoming.preferredDistanceUnit),
        preferredVolumeUnit: Value(incoming.preferredVolumeUnit),
        currencyCode: Value(incoming.currencyCode),
        timezone: Value(incoming.timezone),
        defaultVehicleId: Value(adopted ? requested : null),
        updatedAt: Value(incoming.updatedAt),
        mutationId: Value(_newId()),
      ),
    );
    return adopted;
  }

  // ───────────────────────────────────────── drafts + photos

  /// Drafts are unsaved typing, not history, so replace does not clear
  /// them wholesale. But drafts are looked up by vehicle
  /// (`DraftsRepository.openDraftForVehicle`), so a draft whose vehicle
  /// the import destroyed is unreachable by construction — and would
  /// resurface if that vehicle id ever returned in a later import.
  /// Because UUIDs are stable across devices, importing your own archive
  /// normally keeps every draft.
  ///
  /// `photo_refs.draft_id` is a foreign key with no `ON DELETE CASCADE`,
  /// so its rows go first.
  Future<_DraftReconcile> _reconcileDrafts(Set<String> keptVehicleIds) async {
    final doomed = await _draftsWithoutVehicle(keptVehicleIds);
    if (doomed.isEmpty) {
      return const _DraftReconcile(draftsDeleted: 0, photoIds: <String>[]);
    }

    final photoIds = <String>[];
    for (final draftId in doomed) {
      final refs = await (db.select(db.photoRefs)
            ..where((p) => p.draftId.equals(draftId)))
          .get();
      photoIds.addAll(refs.map((r) => r.id));
      await (db.delete(db.photoRefs)
            ..where((p) => p.draftId.equals(draftId)))
          .go();
    }

    var deleted = 0;
    for (final draftId in doomed) {
      deleted +=
          await (db.delete(db.drafts)..where((d) => d.id.equals(draftId))).go();
    }

    return _DraftReconcile(draftsDeleted: deleted, photoIds: photoIds);
  }

  /// Ids of drafts whose `vehicle_id` is absent from [keptVehicleIds].
  ///
  /// A draft with a null `vehicle_id` is left alone: it is reachable
  /// again as soon as the user picks a vehicle, so it is not orphaned.
  Future<List<String>> _draftsWithoutVehicle(Set<String> keptVehicleIds) async {
    final drafts = await db.select(db.drafts).get();
    return drafts
        .where((d) {
          final vehicleId = d.vehicleId;
          return vehicleId != null && !keptVehicleIds.contains(vehicleId);
        })
        .map((d) => d.id)
        .toList();
  }

  Future<int> _countAll(TableInfo<Table, dynamic> table) async {
    final expression = countAll();
    final row =
        await (db.selectOnly(table)..addColumns([expression])).getSingle();
    return row.read(expression) ?? 0;
  }
}

class _DraftReconcile {
  const _DraftReconcile({required this.draftsDeleted, required this.photoIds});

  final int draftsDeleted;
  final List<String> photoIds;
}
