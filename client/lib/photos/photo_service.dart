/// Coordinator for the receipt-photo lifecycle.
///
/// Spec: `docs/specs/photo-pipeline.md` §Lifecycle + §"Cleanup triggers".
///
/// This is the second of two impure files in `client/lib/photos/` (see
/// `photo_store.dart`): it is the documented bridge between the pure byte /
/// TTL logic, the `photo_refs` table, and the sandbox files. Ordering rules
/// that keep the two stores consistent live here and nowhere else.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../db/repositories/photo_refs_repository.dart';
import '../db/repositories/protocol_writes.dart';
import 'photo_processing.dart';
import 'photo_store.dart';
import 'photo_ttl.dart';

/// Signature of the byte pipeline, so the isolate hop can be swapped for a
/// direct call in tests.
typedef PhotoProcessor = Future<ProcessedPhoto> Function(
  Uint8List bytes,
  DateTime now,
);

/// Runs the pipeline on a background isolate.
///
/// `package:image` decodes and re-encodes in pure Dart, and a 12 MP camera
/// photo is a few hundred milliseconds of work — enough to drop frames if it
/// ran on the UI isolate while the user is standing at a pump.
Future<ProcessedPhoto> processPhotoInIsolate(Uint8List bytes, DateTime now) =>
    compute(_processInIsolate, (bytes: bytes, now: now));

ProcessedPhoto _processInIsolate(({Uint8List bytes, DateTime now}) request) =>
    processPhotoBytes(request.bytes, now: request.now);

/// Runs the pipeline in-process. Tests use this to stay off real isolates.
Future<ProcessedPhoto> processPhotoInProcess(
  Uint8List bytes,
  DateTime now,
) async =>
    processPhotoBytes(bytes, now: now);

/// A stored photo plus its file, ready for the UI to render.
class PhotoAttachment {
  const PhotoAttachment({required this.row, required this.file});

  final PhotoRefRow row;
  final File file;

  String get id => row.id;
  int get byteSize => row.byteSize;
  DateTime get capturedAt => DateTime.parse(row.capturedAt);
  DateTime get ttlExpiresAt => DateTime.parse(row.ttlExpiresAt);
}

/// What a cleanup pass removed. Surfaced for tests and the debug page.
class PhotoSweepResult {
  const PhotoSweepResult({
    this.expiredPurged = 0,
    this.orphanRowsDropped = 0,
    this.orphanFilesDeleted = 0,
  });

  /// Rows past their TTL, file and row both gone.
  final int expiredPurged;

  /// Rows whose file had already vanished.
  final int orphanRowsDropped;

  /// Files with no surviving row.
  final int orphanFilesDeleted;

  int get total => expiredPurged + orphanRowsDropped + orphanFilesDeleted;

  @override
  String toString() => 'PhotoSweepResult(expired: $expiredPurged, '
      'orphanRows: $orphanRowsDropped, orphanFiles: $orphanFilesDeleted)';
}

class PhotoService {
  PhotoService({
    required PhotoRefsRepository refs,
    required PhotoStore store,
    String Function()? newId,
    DateTime Function()? clock,
    PhotoProcessor? processor,
  })  : _refs = refs,
        _store = store,
        _newId = newId ?? newUuid,
        _clock = clock ?? DateTime.now,
        _process = processor ?? processPhotoInIsolate;

  /// Production wiring — `photo_refs` plus the app sandbox.
  factory PhotoService.forDatabase(AppDatabase db) => PhotoService(
        refs: PhotoRefsRepository(db),
        store: PhotoStore.appSandbox(),
      );

  final PhotoRefsRepository _refs;
  final PhotoStore _store;
  final String Function() _newId;
  final DateTime Function() _clock;
  final PhotoProcessor _process;

  /// Cleanup is throttled per process rather than per widget, because the
  /// Log page is rebuilt every time the user switches tabs.
  static DateTime? _lastSweepAt;

  /// Why the last throttled sweep failed, if it did. Cleanup must never
  /// break the Log tab, so failures are recorded instead of thrown.
  String? lastSweepError;

  // ---------------------------------------------------------------- read

  Future<List<PhotoAttachment>> listForDraft(String draftId) async {
    final rows = await _refs.listForDraft(draftId);
    return Future.wait(rows.map(_attachmentFor));
  }

  Future<int> countForDraft(String draftId) => _refs.countForDraft(draftId);

  // --------------------------------------------------------------- write

  /// Processes [bytes] and persists the result: file first, then the row.
  ///
  /// The cap is checked before the expensive decode so a user at the limit
  /// gets an immediate error, and again inside the repository so no other
  /// caller can slip past it.
  Future<PhotoAttachment> attachFromBytes({
    required String draftId,
    required Uint8List bytes,
  }) async {
    if (await _refs.countForDraft(draftId) >= maxPhotosPerDraft) {
      throw PhotoLimitExceededException(draftId, maxPhotosPerDraft);
    }

    final processed = await _process(bytes, _clock());
    final id = _newId();
    await _store.write(id, processed.bytes);

    try {
      final row = await _refs.insert(
        id: id,
        draftId: draftId,
        capturedAt: processed.capturedAt,
        byteSize: processed.byteSize,
        sha256Hex: processed.sha256Hex,
        ttlExpiresAt: captureTtlExpiry(processed.capturedAt),
      );
      return await _attachmentFor(row);
    } catch (_) {
      // Row write lost (cap race, FK violation): the file would otherwise
      // linger with nothing pointing at it.
      await _store.delete(id);
      rethrow;
    }
  }

  /// User-initiated delete — immediate, not on TTL.
  Future<bool> delete(String photoId) async {
    await _store.delete(photoId);
    return _refs.deleteById(photoId);
  }

  /// Removes every photo attached to [draftId]. Call this **before**
  /// discarding the draft row: `photo_refs.draft_id` is a foreign key with
  /// no ON DELETE CASCADE, so the draft delete would otherwise fail.
  Future<int> purgeDraft(String draftId) async {
    final rows = await _refs.listForDraft(draftId);
    for (final row in rows) {
      await _store.delete(row.id);
    }
    return _refs.deleteForDraft(draftId);
  }

  /// Shortens the TTL of the draft's photos once it has been promoted to a
  /// fill-up. Never extends an existing expiry.
  Future<int> onDraftCompleted(String draftId, {DateTime? completedAt}) async {
    final at = (completedAt ?? _clock()).toUtc();
    final rows = await _refs.listForDraft(draftId);
    var shortened = 0;
    for (final row in rows) {
      final current = DateTime.parse(row.ttlExpiresAt);
      final next = completionTtlExpiry(completedAt: at, currentExpiry: current);
      if (next.isBefore(current)) {
        await _refs.setTtl(row.id, next);
        shortened++;
      }
    }
    return shortened;
  }

  // ------------------------------------------------------------- cleanup

  /// Full cleanup pass: expired rows, orphan rows, orphan files.
  ///
  /// Crash-safe ordering per spec — the file goes first, so an interruption
  /// leaves a row with no file, which the next pass drops.
  Future<PhotoSweepResult> sweep({DateTime? now}) async {
    final at = (now ?? _clock()).toUtc();

    var expiredPurged = 0;
    var orphanRowsDropped = 0;

    for (final row in await _refs.listAll()) {
      final expired = isPhotoExpired(
        ttlExpiresAt: DateTime.parse(row.ttlExpiresAt),
        now: at,
      );
      final hasFile = await _store.exists(row.id);

      if (expired) {
        await _store.delete(row.id);
        await _refs.deleteById(row.id);
        expiredPurged++;
      } else if (!hasFile) {
        await _refs.deleteById(row.id);
        orphanRowsDropped++;
      }
    }

    final liveIds = (await _refs.listAll()).map((r) => r.id).toSet();
    var orphanFilesDeleted = 0;
    for (final id in await _store.storedIds()) {
      if (liveIds.contains(id)) continue;
      await _store.delete(id);
      orphanFilesDeleted++;
    }

    _lastSweepAt = at;
    return PhotoSweepResult(
      expiredPurged: expiredPurged,
      orphanRowsDropped: orphanRowsDropped,
      orphanFilesDeleted: orphanFilesDeleted,
    );
  }

  /// App-foreground cleanup hook, throttled to once per [minInterval].
  ///
  /// Returns null when the throttle window is still open or the sweep
  /// failed. A broken sandbox must not stop the user logging a fill-up, so
  /// the failure is recorded in [lastSweepError] and retried next window.
  Future<PhotoSweepResult?> sweepThrottled({
    Duration minInterval = const Duration(hours: 1),
    DateTime? now,
  }) async {
    final at = (now ?? _clock()).toUtc();
    final last = _lastSweepAt;
    if (last != null && at.difference(last).abs() < minInterval) return null;

    // Claim the window up front so concurrent callers don't both sweep.
    _lastSweepAt = at;
    try {
      final result = await sweep(now: at);
      lastSweepError = null;
      return result;
    } catch (error) {
      lastSweepError = error.toString();
      return null;
    }
  }

  @visibleForTesting
  static void resetSweepThrottle() => _lastSweepAt = null;

  // ------------------------------------------------------------- helpers

  Future<PhotoAttachment> _attachmentFor(PhotoRefRow row) async =>
      PhotoAttachment(row: row, file: await _store.fileFor(row.id));
}
