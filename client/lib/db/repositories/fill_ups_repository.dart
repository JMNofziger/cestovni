/// Repository for the `fill_ups` table.
///
/// Spec: `docs/specs/data-model.md` §`fill_ups` + ADR 002 (protocol
/// columns) + `docs/specs/consumption-math.md` §"Validation rules at
/// entry" + `docs/product/ux/DATA_CONTRACTS.md` §"Fill-up entry
/// contract".
///
/// Validation is the responsibility of `client/lib/consumption/
/// validation.dart#validateInsert`; callers must run it BEFORE calling
/// [FillUpsRepository.create] / [FillUpsRepository.amend]. The repo
/// trusts its inputs and writes them as-is so the validation rules
/// have one canonical implementation path.
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Form-time inputs for inserting a fill-up. All canonical SI-INT64
/// (`odometer_m`, `volume_uL`, `total_price_cents`); see
/// `docs/specs/si-units.md`.
class FillUpDraft {
  const FillUpDraft({
    required this.vehicleId,
    required this.filledAt,
    required this.odometerM,
    required this.volumeUL,
    required this.totalPriceCents,
    required this.currencyCode,
    required this.isFull,
    this.missedBefore = false,
    this.odometerReset = false,
    this.notes,
  });

  final String vehicleId;
  final DateTime filledAt;
  final int odometerM;
  final int volumeUL;
  final int totalPriceCents;
  final String currencyCode;
  final bool isFull;
  final bool missedBefore;
  final bool odometerReset;
  final String? notes;
}

class FillUpsRepository {
  FillUpsRepository(
    this._db, {
    String Function()? newId,
    String Function()? now,
  })  : _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  // --------------------------------------------------------------- read

  /// Live (non-soft-deleted) fill-ups for one vehicle, newest first.
  /// Ordering matches `docs/product/ux/DATA_CONTRACTS.md` §"History
  /// feed contract" tie-break (`event_datetime DESC, created_at DESC,
  /// id DESC`); we don't store a separate `created_at` so the local
  /// fall-through is `(filled_at DESC, id DESC)`.
  Stream<List<FillUpRow>> watchForVehicle(String vehicleId) {
    final query = _db.select(_db.fillUps)
      ..where((f) => f.vehicleId.equals(vehicleId) & f.deletedAt.isNull())
      ..orderBy([
        (f) => OrderingTerm.desc(f.filledAt),
        (f) => OrderingTerm.desc(f.id),
      ]);
    return query.watch();
  }

  /// One-shot variant of [watchForVehicle], for tests + math kick-offs.
  Future<List<FillUpRow>> listForVehicle(String vehicleId) {
    final query = _db.select(_db.fillUps)
      ..where((f) => f.vehicleId.equals(vehicleId) & f.deletedAt.isNull())
      ..orderBy([
        (f) => OrderingTerm.asc(f.filledAt),
        (f) => OrderingTerm.asc(f.id),
      ]);
    return query.get();
  }

  /// Single-row lookup; null on miss. Honors soft-delete (a deleted
  /// row returns null).
  Future<FillUpRow?> findById(String id) {
    final query = _db.select(_db.fillUps)
      ..where((f) => f.id.equals(id) & f.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  // --------------------------------------------------------------- write

  /// Insert a new fill-up. Caller must have already validated via
  /// `validateInsert` from the consumption module. Returns the new id.
  Future<String> create(FillUpDraft draft) async {
    final id = _newId();
    await _db.into(_db.fillUps).insert(
          FillUpsCompanion(
            id: Value(id),
            vehicleId: Value(draft.vehicleId),
            filledAt: Value(draft.filledAt.toUtc().toIso8601String()),
            odometerM: Value(draft.odometerM),
            volumeUL: Value(draft.volumeUL),
            totalPriceCents: Value(draft.totalPriceCents),
            currencyCode: Value(draft.currencyCode),
            isFull: Value(draft.isFull),
            missedBefore: Value(draft.missedBefore),
            odometerReset: Value(draft.odometerReset),
            notes: Value(draft.notes),
            updatedAt: Value(_now()),
            mutationId: Value(_newId()),
          ),
        );
    return id;
  }

  /// Amend an existing live fill-up. Returns true if a row was
  /// updated; false if the row is missing or already soft-deleted.
  /// Caller is responsible for re-running validation before calling.
  Future<bool> amend(String id, FillUpDraft draft) async {
    final updated = await (_db.update(_db.fillUps)
          ..where((f) => f.id.equals(id) & f.deletedAt.isNull()))
        .write(
      FillUpsCompanion(
        vehicleId: Value(draft.vehicleId),
        filledAt: Value(draft.filledAt.toUtc().toIso8601String()),
        odometerM: Value(draft.odometerM),
        volumeUL: Value(draft.volumeUL),
        totalPriceCents: Value(draft.totalPriceCents),
        currencyCode: Value(draft.currencyCode),
        isFull: Value(draft.isFull),
        missedBefore: Value(draft.missedBefore),
        odometerReset: Value(draft.odometerReset),
        notes: Value(draft.notes),
        updatedAt: Value(_now()),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }

  /// Soft-delete: set `deleted_at`. The row stays for export but
  /// drops out of math (per `consumption-math.md` §"Fill-up
  /// lifecycle") and history feeds.
  Future<bool> softDelete(String id) async {
    final ts = _now();
    final updated = await (_db.update(_db.fillUps)
          ..where((f) => f.id.equals(id) & f.deletedAt.isNull()))
        .write(
      FillUpsCompanion(
        deletedAt: Value(ts),
        updatedAt: Value(ts),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }
}
