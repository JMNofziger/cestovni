/// Repository for the client-only `drafts` table.
///
/// Spec: `docs/specs/data-model.md` §"Client-only tables" +
/// `docs/specs/consumption-math.md` §"Fill-up lifecycle" +
/// `docs/product/ux/DELIVERY_ACCEPTANCE.md` §Log → must-ship draft
/// flow.
///
/// **v1 scope** (CES-39): one open draft per vehicle. Re-saving an
/// existing draft for the same vehicle overwrites it; promoting it to
/// a `fill_ups` row sets `completed_at` so the cleanup pass can drop
/// the draft after the photo TTL window (handled in M2 / M3).
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Snapshot of the in-progress fill-up form. All fields nullable so
/// the user can save a partially-filled form. Booleans are tri-state:
/// null means "user hasn't decided yet".
class DraftSnapshot {
  const DraftSnapshot({
    required this.vehicleId,
    this.filledAt,
    this.odometerM,
    this.volumeUL,
    this.totalPriceCents,
    this.currencyCode,
    this.isFull,
    this.missedBefore,
    this.odometerReset,
    this.notes,
  });

  final String? vehicleId;
  final DateTime? filledAt;
  final int? odometerM;
  final int? volumeUL;
  final int? totalPriceCents;
  final String? currencyCode;
  final bool? isFull;
  final bool? missedBefore;
  final bool? odometerReset;
  final String? notes;
}

class DraftsRepository {
  DraftsRepository(
    this._db, {
    String Function()? newId,
    String Function()? now,
  })  : _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  // --------------------------------------------------------------- read

  /// Latest non-promoted draft for the given vehicle, or null when
  /// the user has no open draft. "Open" = `completed_at IS NULL`.
  Future<DraftRow?> openDraftForVehicle(String vehicleId) {
    final query = _db.select(_db.drafts)
      ..where((d) => d.vehicleId.equals(vehicleId) & d.completedAt.isNull())
      ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Stream variant — used by the Log page so it picks up draft saves
  /// from elsewhere (e.g. background outbox cleanup) without manual
  /// re-fetch.
  Stream<DraftRow?> watchOpenDraftForVehicle(String vehicleId) {
    final query = _db.select(_db.drafts)
      ..where((d) => d.vehicleId.equals(vehicleId) & d.completedAt.isNull())
      ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  // --------------------------------------------------------------- write

  /// Save (insert or update) the open draft for the snapshot's
  /// vehicle. v1 keeps a single open draft per vehicle, so an existing
  /// open row is overwritten in place. Returns the draft id.
  Future<String> save(DraftSnapshot snap) async {
    final existing = snap.vehicleId == null
        ? null
        : await openDraftForVehicle(snap.vehicleId!);
    final id = existing?.id ?? _newId();
    if (existing == null) {
      await _db.into(_db.drafts).insert(_companionFor(id, snap, isUpdate: false));
    } else {
      await (_db.update(_db.drafts)..where((d) => d.id.equals(id)))
          .write(_companionFor(id, snap, isUpdate: true));
    }
    return id;
  }

  /// Mark the draft as completed (= promoted to a real fill-up row).
  /// Does NOT delete the draft — photo cleanup (M2) reads
  /// `completed_at` to enforce the 7-day post-completion TTL.
  Future<bool> markCompleted(String draftId) async {
    final updated = await (_db.update(_db.drafts)
          ..where((d) => d.id.equals(draftId)))
        .write(DraftsCompanion(completedAt: Value(_now())));
    return updated > 0;
  }

  /// Discard a draft entirely — row is removed; v1 does not surface a
  /// "trash" view for drafts.
  Future<bool> discard(String draftId) async {
    final removed = await (_db.delete(_db.drafts)
          ..where((d) => d.id.equals(draftId)))
        .go();
    return removed > 0;
  }

  // ------------------------------------------------------------ helpers

  DraftsCompanion _companionFor(
    String id,
    DraftSnapshot snap, {
    required bool isUpdate,
  }) {
    final filledAt = snap.filledAt?.toUtc().toIso8601String();
    return DraftsCompanion(
      id: Value(id),
      vehicleId: Value(snap.vehicleId),
      createdAt: isUpdate ? const Value.absent() : Value(_now()),
      filledAt: Value(filledAt),
      odometerM: Value(snap.odometerM),
      volumeUL: Value(snap.volumeUL),
      totalPriceCents: Value(snap.totalPriceCents),
      currencyCode: Value(snap.currencyCode),
      isFull: Value(snap.isFull == null ? null : (snap.isFull! ? 1 : 0)),
      missedBefore: Value(
        snap.missedBefore == null ? null : (snap.missedBefore! ? 1 : 0),
      ),
      odometerReset: Value(
        snap.odometerReset == null ? null : (snap.odometerReset! ? 1 : 0),
      ),
      notes: Value(snap.notes),
      completedAt: const Value.absent(),
    );
  }
}
