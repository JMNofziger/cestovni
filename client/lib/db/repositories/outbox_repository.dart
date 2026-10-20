/// Client-side outbox repository (CES-44 minimal slice).
///
/// Implements the **client outbox** contract from
/// `docs/specs/sync-protocol.md` §"Client outbox (local only)" + §"Fill-up
/// lifecycle". The outbox is local-only — never sent as-is to the server.
/// Each pending row carries the `mutation_id` generated at enqueue and
/// reused on every retry so the server can dedupe.
///
/// Coalescing rule (per §"Fill-up lifecycle"): multiple pending `update`
/// rows for the same `(table, row_id)` are merged into a single entry
/// before send. We do **not** coalesce across `op` boundaries: a pending
/// `insert` followed by an `update` keeps the `insert` (server only ever
/// applies the latest payload), and a `soft_delete` supersedes pending
/// inserts/updates for the same row.
///
/// Drafts are **not** enqueued — only `complete` (`create`), `amend`,
/// and `soft_delete` transitions on the source repos call into this
/// repo, inside the same Drift transaction.
///
/// Rows whose `last_error` starts with [outboxDeadLetterPrefix] have
/// exhausted non-429 retries (or hit a non-retriable HTTP status).
/// [pendingBatch] skips them. CES-45 owns the user-facing list.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Prefix stored in `outbox.last_error` when a row leaves the flush
/// queue. No extra column: the gate-slice schema has nowhere else to
/// mark it.
const String outboxDeadLetterPrefix = 'dead-letter: ';

/// Allowed `op` values per `client/lib/db/tables/outbox.dart` CHECK
/// constraint and `sync-protocol.md`.
enum OutboxOp {
  insert('insert'),
  update('update'),
  softDelete('soft_delete');

  const OutboxOp(this.wire);

  final String wire;
}

class OutboxRepository {
  OutboxRepository(
    this._db, {
    String Function()? newId,
    String Function()? now,
  })  : _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  // ---------------------------------------------------------------- enqueue

  /// Enqueue a fresh outbox entry on the **insert** lifecycle transition.
  ///
  /// MUST be called inside the same `transaction` as the row write so a
  /// crash between the two cannot leak a fill-up that was never queued.
  Future<int> enqueueInsert({
    required String table,
    required String rowId,
    required Map<String, dynamic> payload,
  }) {
    return _insertRow(
      table: table,
      op: OutboxOp.insert,
      rowId: rowId,
      payloadJson: jsonEncode(payload),
    );
  }

  /// Enqueue or **coalesce** an `update` on the lifecycle transition.
  ///
  /// If a pending `insert` exists for the same `(table, row_id)`, we
  /// rewrite its `payload_json` instead of inserting a second row —
  /// the server only ever sees the latest snapshot, and this avoids
  /// double-applying a row that hasn't synced yet. If a pending
  /// `update` already exists, we overwrite its payload (latest wins).
  Future<int> enqueueUpdate({
    required String table,
    required String rowId,
    required Map<String, dynamic> payload,
  }) async {
    final payloadJson = jsonEncode(payload);

    final existing = await (_db.select(_db.outbox)
          ..where((o) =>
              o.table_.equals(table) &
              o.rowId.equals(rowId) &
              o.op.isIn([OutboxOp.insert.wire, OutboxOp.update.wire])))
        .get();

    if (existing.isNotEmpty) {
      final target = existing.first;
      await (_db.update(_db.outbox)..where((o) => o.id.equals(target.id)))
          .write(OutboxCompanion(payloadJson: Value(payloadJson)));
      return target.id;
    }

    return _insertRow(
      table: table,
      op: OutboxOp.update,
      rowId: rowId,
      payloadJson: payloadJson,
    );
  }

  /// Enqueue a `soft_delete`. Per protocol §Fill-up lifecycle the
  /// server sets `deleted_at`; payload is `null`.
  ///
  /// A `soft_delete` **supersedes** any pending `insert`/`update` for
  /// the same row: if the local row never synced, there is no point
  /// telling the server to insert-then-delete it — we just drop the
  /// pending rows and let the soft_delete idempotency handle the
  /// (extremely unlikely) race where the server already knows the row
  /// by `mutation_id`.
  Future<int> enqueueSoftDelete({
    required String table,
    required String rowId,
  }) async {
    await (_db.delete(_db.outbox)
          ..where((o) =>
              o.table_.equals(table) &
              o.rowId.equals(rowId) &
              o.op.isIn([OutboxOp.insert.wire, OutboxOp.update.wire])))
        .go();

    return _insertRow(
      table: table,
      op: OutboxOp.softDelete,
      rowId: rowId,
      payloadJson: null,
    );
  }

  Future<int> _insertRow({
    required String table,
    required OutboxOp op,
    required String rowId,
    required String? payloadJson,
  }) {
    return _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            mutationId: _newId(),
            table_: table,
            op: op.wire,
            rowId: rowId,
            payloadJson: Value(payloadJson),
            enqueuedAt: _now(),
          ),
        );
  }

  // ---------------------------------------------------------------- read

  /// Pending entries oldest-first, capped to the protocol batch ceiling
  /// of 100 (`sync-protocol.md` §POST /mutations). Dead-lettered rows
  /// stay in the table but are not sent again.
  Future<List<OutboxRow>> pendingBatch({int limit = 100}) {
    final clamped = limit.clamp(1, 100);
    final query = _db.select(_db.outbox)
      ..where(
        (o) =>
            o.lastError.isNull() |
            o.lastError.like('$outboxDeadLetterPrefix%').not(),
      )
      ..orderBy([(o) => OrderingTerm.asc(o.id)])
      ..limit(clamped);
    return query.get();
  }

  /// One-shot pending count — handy for the Debug page indicator.
  Future<int> pendingCount() async {
    final count = countAll();
    final row = await (_db.selectOnly(_db.outbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Stream<int> watchPendingCount() {
    final count = countAll();
    final query = _db.selectOnly(_db.outbox)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Every pending `mutation_id`, unsorted. Export hashes the sorted set.
  Future<List<String>> pendingMutationIds() async {
    final rows = await _db.select(_db.outbox).get();
    return [for (final r in rows) r.mutationId];
  }

  // ---------------------------------------------------------------- mutate

  /// Drop a row after the server returns `applied` or `duplicate`.
  Future<void> deleteById(int id) async {
    await (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();
  }

  /// Bump `attempts` and persist the latest error envelope for diagnostics.
  Future<void> recordRetry(int id, {required String lastError}) async {
    final row = await (_db.select(_db.outbox)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(lastError),
      ),
    );
  }

  /// Record one sync failure.
  ///
  /// [towardDeadLetter] is false for HTTP 429: `attempts` still
  /// increments, but those tries never cross the 6-failure ceiling.
  /// Returns true when this call moved the row to the dead-letter mark.
  Future<bool> recordSyncFailure(
    int id, {
    required String message,
    required bool towardDeadLetter,
  }) async {
    final row = await (_db.select(_db.outbox)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return false;
    final nextNon429 = _non429Count(row) + (towardDeadLetter ? 1 : 0);
    final dead = towardDeadLetter && nextNon429 >= 6;
    final stored = dead
        ? '$outboxDeadLetterPrefix$message'
        : 'n429=$nextNon429; $message';
    await (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(stored),
      ),
    );
    return dead;
  }

  /// Non-retriable failure (HTTP 400/403/409, or a rejected mutation
  /// with `retriable: false`). Leaves the flush queue immediately.
  Future<void> markDeadLetter(int id, {required String message}) async {
    final row = await (_db.select(_db.outbox)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value('$outboxDeadLetterPrefix$message'),
      ),
    );
  }

  static int _non429Count(OutboxRow row) {
    final err = row.lastError;
    if (err == null) return 0;
    final match = RegExp(r'^n429=(\d+);').firstMatch(err);
    if (match == null) return 0;
    return int.parse(match.group(1)!);
  }
}
