/// Repository for the client-only `photo_refs` table.
///
/// Spec: `docs/specs/photo-pipeline.md` + `docs/specs/data-model.md`
/// §"Client-only tables".
///
/// `photo_refs` carries no protocol columns and is absent from the outbox
/// `table` CHECK list, so nothing here enqueues a mutation — receipt photos
/// never reach the server. This repository is deliberately DB-only: file IO
/// and the delete-file-then-row ordering live in
/// `client/lib/photos/photo_service.dart`.
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Soft product limit from `photo-pipeline.md` §"Soft limits". Enforced at
/// the write boundary so no UI path can exceed it.
const int maxPhotosPerDraft = 5;

/// Raised when a draft already holds [maxPhotosPerDraft] photos.
class PhotoLimitExceededException implements Exception {
  const PhotoLimitExceededException(this.draftId, this.limit);

  final String draftId;
  final int limit;

  @override
  String toString() =>
      'PhotoLimitExceededException: draft $draftId already holds $limit photos';
}

class PhotoRefsRepository {
  PhotoRefsRepository(
    this._db, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final AppDatabase _db;
  final String Function() _newId;

  // --------------------------------------------------------------- read

  /// Photos attached to [draftId], oldest first (capture order).
  Future<List<PhotoRefRow>> listForDraft(String draftId) {
    final query = _db.select(_db.photoRefs)
      ..where((p) => p.draftId.equals(draftId))
      ..orderBy([(p) => OrderingTerm.asc(p.capturedAt)]);
    return query.get();
  }

  Future<int> countForDraft(String draftId) async =>
      (await listForDraft(draftId)).length;

  Future<PhotoRefRow?> findById(String id) {
    final query = _db.select(_db.photoRefs)..where((p) => p.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<List<PhotoRefRow>> listAll() {
    final query = _db.select(_db.photoRefs)
      ..orderBy([(p) => OrderingTerm.asc(p.capturedAt)]);
    return query.get();
  }

  /// Rows whose TTL has elapsed at [now]. String comparison is safe because
  /// `ttl_expires_at` is always written as ISO-8601 UTC.
  Future<List<PhotoRefRow>> listExpired(DateTime now) {
    final cutoff = now.toUtc().toIso8601String();
    final query = _db.select(_db.photoRefs)
      ..where((p) => p.ttlExpiresAt.isSmallerOrEqualValue(cutoff));
    return query.get();
  }

  // --------------------------------------------------------------- write

  /// Records a photo that has already been written to the sandbox. Returns
  /// the inserted row.
  ///
  /// Throws [PhotoLimitExceededException] when the draft is already at
  /// [maxPhotosPerDraft]; the caller is expected to have written no file
  /// yet, or to remove the one it wrote.
  Future<PhotoRefRow> insert({
    required String draftId,
    required DateTime capturedAt,
    required int byteSize,
    required String sha256Hex,
    required DateTime ttlExpiresAt,
    String? id,
  }) async {
    if (await countForDraft(draftId) >= maxPhotosPerDraft) {
      throw PhotoLimitExceededException(draftId, maxPhotosPerDraft);
    }
    final row = PhotoRefRow(
      id: id ?? _newId(),
      draftId: draftId,
      capturedAt: capturedAt.toUtc().toIso8601String(),
      byteSize: byteSize,
      sha256: sha256Hex,
      ttlExpiresAt: ttlExpiresAt.toUtc().toIso8601String(),
    );
    await _db.into(_db.photoRefs).insert(row);
    return row;
  }

  /// Hard-deletes a single row. Callers delete the file first so a crash
  /// between the two leaves an orphan row, which the next sweep drops.
  Future<bool> deleteById(String id) async {
    final removed =
        await (_db.delete(_db.photoRefs)..where((p) => p.id.equals(id))).go();
    return removed > 0;
  }

  Future<int> deleteForDraft(String draftId) {
    return (_db.delete(_db.photoRefs)..where((p) => p.draftId.equals(draftId)))
        .go();
  }

  /// Overwrites `ttl_expires_at` for a single row.
  Future<bool> setTtl(String id, DateTime ttlExpiresAt) async {
    final updated = await (_db.update(_db.photoRefs)
          ..where((p) => p.id.equals(id)))
        .write(PhotoRefsCompanion(
      ttlExpiresAt: Value(ttlExpiresAt.toUtc().toIso8601String()),
    ));
    return updated > 0;
  }
}
