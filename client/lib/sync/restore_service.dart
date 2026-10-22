import '../db/app_database.dart';
import 'restore_apply.dart';
import 'restore_telemetry.dart';
import 'sync_client.dart';

/// Backed-up tables in restore order. Core tables unblock the UI.
const List<String> restoreCoreTables = ['vehicles', 'fill_ups'];

const List<String> restoreBackgroundTables = [
  'maintenance_rules',
  'maintenance_events',
  'settings',
];

const List<String> restoreTableOrder = [
  ...restoreCoreTables,
  ...restoreBackgroundTables,
];

/// `sync-protocol.md` default page size.
const int restorePageLimit = 200;

enum RestoreReason {
  coldStart('cold_start'),
  userInitiated('user_initiated'),
  reinstall('reinstall');

  const RestoreReason(this.wire);
  final String wire;
}

enum RestoreRunPhase { idle, running, failed, cancelled, complete }

enum RestoreTablePhase { waiting, running, done, failed }

class RestoreTableProgress {
  const RestoreTableProgress({
    required this.table,
    required this.received,
    required this.total,
    required this.phase,
  });

  final String table;
  final int received;
  final int total;
  final RestoreTablePhase phase;

  RestoreTableProgress copyWith({
    int? received,
    int? total,
    RestoreTablePhase? phase,
  }) {
    return RestoreTableProgress(
      table: table,
      received: received ?? this.received,
      total: total ?? this.total,
      phase: phase ?? this.phase,
    );
  }
}

class RestoreSnapshot {
  const RestoreSnapshot({
    required this.phase,
    required this.tables,
    required this.rowsApplied,
    this.message,
    this.statusCode,
  });

  const RestoreSnapshot.idle()
      : phase = RestoreRunPhase.idle,
        tables = const [],
        rowsApplied = 0,
        message = null,
        statusCode = null;

  final RestoreRunPhase phase;
  final List<RestoreTableProgress> tables;
  final int rowsApplied;
  final String? message;
  final int? statusCode;

  bool get coreReady => restoreCoreTables.every(
        (name) => tables.any(
          (t) => t.table == name && t.phase == RestoreTablePhase.done,
        ),
      );

  bool get backgroundRunning =>
      phase == RestoreRunPhase.running && coreReady;
}

/// Cursor-paginated restore. Each page and its cursor commit together.
/// [cancel] stops after the current page. A later [run] resumes from
/// the stored cursors.
class RestoreService {
  RestoreService({
    required AppDatabase db,
    required this.client,
    DateTime Function()? clock,
    this.pageLimit = restorePageLimit,
  })  : applier = RestoreApplier(db),
        _clock = clock ?? DateTime.now;

  final SyncClient client;
  final RestoreApplier applier;
  final int pageLimit;
  final DateTime Function() _clock;

  bool _cancel = false;

  void cancel() => _cancel = true;

  Stream<RestoreSnapshot> run({required RestoreReason reason}) async* {
    final started = _clock();
    restoreTelemetry('restore_start', {'reason': reason.wire});
    var rowsApplied = 0;
    final progress = <String, RestoreTableProgress>{
      for (final table in restoreTableOrder)
        table: RestoreTableProgress(
          table: table,
          received: 0,
          total: 0,
          phase: RestoreTablePhase.waiting,
        ),
    };

    RestoreSnapshot snap(RestoreRunPhase phase, {String? message, int? status}) {
      return RestoreSnapshot(
        phase: phase,
        tables: [for (final table in restoreTableOrder) progress[table]!],
        rowsApplied: rowsApplied,
        message: message,
        statusCode: status,
      );
    }

    try {
      final manifest = await client.getRestoreManifest();
      final meta = {for (final t in manifest.tables) t.table: t};
      for (final table in restoreTableOrder) {
        final info = meta[table];
        final total = info?.rowCount ?? 0;
        progress[table] = progress[table]!.copyWith(
          total: total,
          received: await applier.syncedCount(table),
        );
      }
      yield snap(RestoreRunPhase.running);

      for (final table in restoreTableOrder) {
        if (_cancel) {
          _finish('aborted', started, rowsApplied);
          yield snap(RestoreRunPhase.cancelled, message: 'Restore cancelled');
          return;
        }
        final maxVersion = meta[table]?.maxRowVersion ?? 0;
        var cursor = await applier.cursorFor(table);
        progress[table] = progress[table]!.copyWith(
          phase: cursor >= maxVersion
              ? RestoreTablePhase.done
              : RestoreTablePhase.running,
          received: await applier.syncedCount(table),
        );
        yield snap(RestoreRunPhase.running);
        while (cursor < maxVersion) {
          if (_cancel) {
            _finish('aborted', started, rowsApplied);
            yield snap(RestoreRunPhase.cancelled, message: 'Restore cancelled');
            return;
          }
          final previous = cursor;
          final page = await client.getChanges(
            table: table,
            since: cursor,
            limit: pageLimit,
          );
          if (page.hasMore && page.nextSince <= previous) {
            throw StateError('changes cursor did not advance for $table');
          }
          final wrote = await applier.applyPage(
            table: table,
            rows: page.rows,
            nextSince: page.nextSince,
          );
          rowsApplied += wrote;
          cursor = page.nextSince;
          progress[table] = progress[table]!.copyWith(
            received: await applier.syncedCount(table),
            phase: (!page.hasMore || cursor >= maxVersion)
                ? RestoreTablePhase.done
                : RestoreTablePhase.running,
          );
          yield snap(RestoreRunPhase.running);
          if (!page.hasMore) break;
        }
        progress[table] = progress[table]!.copyWith(
          phase: RestoreTablePhase.done,
          received: await applier.syncedCount(table),
        );
        yield snap(RestoreRunPhase.running);
      }
      _finish('ok', started, rowsApplied);
      yield snap(RestoreRunPhase.complete);
    } on SyncHttpError catch (error) {
      _finish('error', started, rowsApplied);
      yield snap(
        RestoreRunPhase.failed,
        message: error.message,
        status: error.statusCode,
      );
    } catch (error) {
      _finish('error', started, rowsApplied);
      yield snap(RestoreRunPhase.failed, message: error.toString());
    }
  }

  void _finish(String outcome, DateTime started, int rowsApplied) {
    final elapsed = _clock().difference(started);
    restoreTelemetry('restore_result', {
      'outcome': outcome,
      'duration_s_bucket': restoreDurationBucket(elapsed),
      'rows_bucket': restoreRowsBucket(rowsApplied),
    });
  }
}
