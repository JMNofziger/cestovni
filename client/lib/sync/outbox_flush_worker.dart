/// Outbox flush worker.
///
/// Drains the local `outbox` table oldest-first in batches of ≤100.
/// `applied` / `duplicate` delete the row. Retriable failures back off
/// `1s → 2s → 4s → 8s → 16s → 30s` with ±20% jitter. HTTP 429 waits
/// `Retry-After` and does not count toward the dead-letter ceiling.
/// Six non-429 failures, or one non-retriable status (400/403/409),
/// mark the row with [outboxDeadLetterPrefix]. HTTP 401 pauses
/// automatic flushes until a manual attempt succeeds.
///
/// [startPeriodicFlush] drains every 30s while the app is in the
/// foreground. [flushOnce] with `manual: true` (the default) always
/// tries, so Debug → Sync now is not blocked by the timer.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../db/app_database.dart' show OutboxRow;
import '../db/repositories/outbox_repository.dart';
import 'sync_client.dart';

/// `failureCount` is 1-based. Attempt 1 waits ~1s, attempt 6 and later
/// wait ~30s. [randomUnit] in `[0, 1]` picks the ±20% jitter; `0.5`
/// is the exact base delay.
Duration syncBackoff(int failureCount, {double Function()? randomUnit}) {
  const steps = <int>[1, 2, 4, 8, 16, 30];
  final index = (failureCount - 1).clamp(0, steps.length - 1);
  final baseSeconds = steps[index];
  final unit = (randomUnit?.call() ?? math.Random().nextDouble()).clamp(
    0.0,
    1.0,
  );
  final factor = 1 + ((unit * 0.4) - 0.2);
  final ms = (baseSeconds * 1000 * factor).round();
  return Duration(milliseconds: ms < 1 ? 1 : ms);
}

/// Result summary for one [OutboxFlushWorker.flushOnce] call.
class FlushReport {
  const FlushReport({
    required this.sent,
    required this.accepted,
    required this.duplicates,
    required this.rejected,
    required this.retriable,
    this.deadLettered = 0,
    this.retryAfterSeconds,
    this.authPaused = false,
    this.lastError,
  });

  /// Mutations included in the batch (≤ 100).
  final int sent;

  /// Server returned `applied`.
  final int accepted;

  /// Server returned `duplicate` (idempotent retry).
  final int duplicates;

  /// Server returned `rejected` with non-retriable error, or the HTTP
  /// status itself was non-retriable.
  final int rejected;

  /// Network / `5xx` / `429` — still queued.
  final int retriable;

  /// Rows marked [outboxDeadLetterPrefix] during this pass.
  final int deadLettered;

  /// Seconds from `Retry-After` when the batch was HTTP 429.
  final int? retryAfterSeconds;

  /// True when this pass stopped on HTTP 401.
  final bool authPaused;

  final String? lastError;

  int get pendingDelta => accepted + duplicates;

  @override
  String toString() =>
      'FlushReport(sent=$sent, accepted=$accepted, dup=$duplicates, '
      'rejected=$rejected, retriable=$retriable, '
      'deadLettered=$deadLettered, authPaused=$authPaused, '
      'retryAfter=$retryAfterSeconds, lastError=$lastError)';
}

class OutboxFlushWorker {
  OutboxFlushWorker({
    required this.outbox,
    required this.client,
    DateTime Function()? clock,
    double Function()? randomUnit,
    this.periodicInterval = const Duration(seconds: 30),
  })  : _clock = clock ?? DateTime.now,
        _randomUnit = randomUnit;

  final OutboxRepository outbox;
  final SyncClient client;
  final Duration periodicInterval;
  final DateTime Function() _clock;
  final double Function()? _randomUnit;

  Timer? _timer;
  bool _inFlight = false;
  bool _authPaused = false;
  int _failureStreak = 0;
  int _consecutive429 = 0;
  DateTime? _notBefore;

  bool get authPaused => _authPaused;

  /// Foreground drain. Does not flush immediately; the shell calls
  /// [flushOnce] on resume as well. Cancel with [stopPeriodicFlush]
  /// when the app backgrounds.
  void startPeriodicFlush() {
    stopPeriodicFlush();
    _timer = Timer.periodic(periodicInterval, (_) {
      flushOnce(manual: false);
    });
  }

  void stopPeriodicFlush() {
    _timer?.cancel();
    _timer = null;
  }

  /// One flush pass.
  ///
  /// [manual] skips the backoff and the 401 pause so Debug → Sync now
  /// and export can try immediately. Automatic passes no-op until
  /// [syncBackoff] or `Retry-After` elapses, and while auth is paused.
  Future<FlushReport> flushOnce({bool manual = true}) async {
    if (_inFlight) {
      return const FlushReport(
        sent: 0,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: 0,
        lastError: 'flush already running',
      );
    }
    if (!manual && _authPaused) {
      return const FlushReport(
        sent: 0,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: 0,
        authPaused: true,
        lastError: 'auth paused',
      );
    }
    final now = _clock();
    if (!manual && _notBefore != null && now.isBefore(_notBefore!)) {
      return FlushReport(
        sent: 0,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: 0,
        lastError: 'backoff until $_notBefore',
      );
    }

    final batch = await outbox.pendingBatch();
    if (batch.isEmpty) {
      return const FlushReport(
        sent: 0,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: 0,
      );
    }

    _inFlight = true;
    try {
      final response = await client.postMutations(batch);
      return await _applyResults(batch, response);
    } on SyncHttpError catch (e) {
      return _onHttpError(batch, e);
    } finally {
      _inFlight = false;
    }
  }

  Future<FlushReport> _applyResults(
    List<OutboxRow> batch,
    MutationResponse response,
  ) async {
    _authPaused = false;
    final byMutationId = {
      for (final r in response.results) r.mutationId: r,
    };

    var accepted = 0;
    var duplicates = 0;
    var rejected = 0;
    var retriable = 0;
    var deadLettered = 0;
    String? lastError;

    for (final row in batch) {
      final result = byMutationId[row.mutationId];
      if (result == null) {
        retriable += 1;
        final dead = await outbox.recordSyncFailure(
          row.id,
          message: 'no result for mutation_id ${row.mutationId}',
          towardDeadLetter: true,
        );
        if (dead) {
          deadLettered += 1;
          retriable -= 1;
        }
        lastError = 'missing result for ${row.mutationId}';
        continue;
      }

      if (result.isAccepted) {
        if (result.status == 'applied') {
          accepted += 1;
        } else {
          duplicates += 1;
        }
        await outbox.deleteById(row.id);
      } else if (result.isRejected) {
        final message = result.errorMessage ?? result.errorCode ?? 'rejected';
        lastError = message;
        if (result.errorRetriable == true) {
          final rateLimited = result.errorCode == 'rate_limited';
          final dead = await outbox.recordSyncFailure(
            row.id,
            message: message,
            towardDeadLetter: !rateLimited,
          );
          if (dead) {
            deadLettered += 1;
          } else {
            retriable += 1;
          }
        } else {
          rejected += 1;
          deadLettered += 1;
          await outbox.markDeadLetter(row.id, message: message);
        }
      } else {
        retriable += 1;
        final dead = await outbox.recordSyncFailure(
          row.id,
          message: 'unknown status: ${result.status}',
          towardDeadLetter: true,
        );
        if (dead) {
          deadLettered += 1;
          retriable -= 1;
        }
        lastError = 'unknown status ${result.status}';
      }
    }

    if (retriable > 0) {
      _failureStreak += 1;
      _notBefore = _clock().add(
        syncBackoff(_failureStreak, randomUnit: _randomUnit),
      );
    } else {
      _failureStreak = 0;
      _consecutive429 = 0;
      _notBefore = null;
    }

    return FlushReport(
      sent: batch.length,
      accepted: accepted,
      duplicates: duplicates,
      rejected: rejected,
      retriable: retriable,
      deadLettered: deadLettered,
      lastError: lastError,
    );
  }

  Future<FlushReport> _onHttpError(
    List<OutboxRow> batch,
    SyncHttpError e,
  ) async {
    if (e.statusCode == 401) {
      _authPaused = true;
      _consecutive429 = 0;
      debugPrint(
        'OutboxFlushWorker: HTTP 401, pausing automatic flush. ${e.message}',
      );
      return FlushReport(
        sent: batch.length,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: batch.length,
        authPaused: true,
        lastError: e.toString(),
      );
    }

    if (e.statusCode == 429) {
      _consecutive429 += 1;
      final headerWait = e.retryAfterSeconds;
      final wait = headerWait ??
          syncBackoff(_consecutive429, randomUnit: _randomUnit).inSeconds;
      final seconds = wait < 1 ? 1 : wait;
      _notBefore = _clock().add(Duration(seconds: seconds));
      for (final row in batch) {
        await outbox.recordSyncFailure(
          row.id,
          message: e.toString(),
          towardDeadLetter: false,
        );
      }
      if (_consecutive429 > 10) {
        debugPrint(
          'OutboxFlushWorker: $_consecutive429 consecutive 429s; '
          'automatic flush waits ${seconds}s',
        );
      }
      return FlushReport(
        sent: batch.length,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: batch.length,
        retryAfterSeconds: seconds,
        lastError: e.toString(),
      );
    }

    if (!e.retriable) {
      for (final row in batch) {
        await outbox.markDeadLetter(row.id, message: e.toString());
      }
      return FlushReport(
        sent: batch.length,
        accepted: 0,
        duplicates: 0,
        rejected: batch.length,
        retriable: 0,
        deadLettered: batch.length,
        lastError: e.toString(),
      );
    }

    _consecutive429 = 0;
    _failureStreak += 1;
    _notBefore = _clock().add(
      syncBackoff(_failureStreak, randomUnit: _randomUnit),
    );
    var deadLettered = 0;
    var retriable = 0;
    for (final row in batch) {
      final dead = await outbox.recordSyncFailure(
        row.id,
        message: e.toString(),
        towardDeadLetter: true,
      );
      if (dead) {
        deadLettered += 1;
      } else {
        retriable += 1;
      }
    }
    return FlushReport(
      sent: batch.length,
      accepted: 0,
      duplicates: 0,
      rejected: deadLettered,
      retriable: retriable,
      deadLettered: deadLettered,
      lastError: e.toString(),
    );
  }
}
