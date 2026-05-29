/// Minimal outbox flush worker (CES-44 gate slice).
///
/// Drains the local `outbox` table oldest-first in batches of ≤100 and
/// posts them to the dev sync stub. On `applied`/`duplicate`, deletes
/// the outbox row. On retriable errors, increments `attempts` + stores
/// `last_error`. Non-retriable errors leave the row in place with the
/// error recorded — full dead-letter UX is CES-45 (out of scope).
///
/// **Single-fill_ups gate slice:** vehicles/settings outbox wiring will
/// follow once the gate is green. There is no automatic retry timer,
/// no exponential backoff, and no rate-limit handling here — the user
/// (or a future foreground hook) triggers flushes.
library;

import '../db/repositories/outbox_repository.dart';
import 'sync_client.dart';

/// Result summary for one [OutboxFlushWorker.flushOnce] call. Useful
/// for surfacing "synced N / pending M" in the Debug page.
class FlushReport {
  const FlushReport({
    required this.sent,
    required this.accepted,
    required this.duplicates,
    required this.rejected,
    required this.retriable,
    this.lastError,
  });

  /// Mutations included in the batch (≤ 100).
  final int sent;

  /// Server returned `applied`.
  final int accepted;

  /// Server returned `duplicate` (idempotent retry).
  final int duplicates;

  /// Server returned `rejected` with non-retriable error.
  final int rejected;

  /// Network / `5xx` / `401` / `429` — retried on next flush.
  final int retriable;

  final String? lastError;

  int get pendingDelta => accepted + duplicates;

  @override
  String toString() =>
      'FlushReport(sent=$sent, accepted=$accepted, dup=$duplicates, '
      'rejected=$rejected, retriable=$retriable, lastError=$lastError)';
}

class OutboxFlushWorker {
  OutboxFlushWorker({required this.outbox, required this.client});

  final OutboxRepository outbox;
  final SyncClient client;

  /// Run one flush pass. Returns a [FlushReport]. Does NOT loop — the
  /// caller decides whether to call again (e.g. on app resume, manual
  /// trigger, or post-save). Safe to call when the outbox is empty
  /// (returns a zeroed report without hitting the network).
  Future<FlushReport> flushOnce() async {
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

    try {
      final response = await client.postMutations(batch);
      final byMutationId = {
        for (final r in response.results) r.mutationId: r,
      };

      var accepted = 0;
      var duplicates = 0;
      var rejected = 0;
      var retriable = 0;
      String? lastError;

      for (final row in batch) {
        final result = byMutationId[row.mutationId];
        if (result == null) {
          // Server dropped the mutation from the response — treat as
          // retriable so we don't lose it on the next pass.
          retriable += 1;
          await outbox.recordRetry(
            row.id,
            lastError: 'no result for mutation_id ${row.mutationId}',
          );
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
          if (result.errorRetriable == true) {
            retriable += 1;
            await outbox.recordRetry(
              row.id,
              lastError: result.errorMessage ?? result.errorCode ?? 'rejected',
            );
          } else {
            rejected += 1;
            await outbox.recordRetry(
              row.id,
              lastError: result.errorMessage ?? result.errorCode ?? 'rejected',
            );
          }
          lastError =
              result.errorMessage ?? result.errorCode ?? 'rejected';
        } else {
          // Unknown status — keep the row + record so the user can
          // diagnose. CES-45 dead-letter UX will surface this.
          retriable += 1;
          await outbox.recordRetry(
            row.id,
            lastError: 'unknown status: ${result.status}',
          );
          lastError = 'unknown status ${result.status}';
        }
      }

      return FlushReport(
        sent: batch.length,
        accepted: accepted,
        duplicates: duplicates,
        rejected: rejected,
        retriable: retriable,
        lastError: lastError,
      );
    } on SyncHttpError catch (e) {
      // Batch-level failure — record on every row so the user sees
      // why the flush stalled, and keep them queued for next attempt.
      for (final row in batch) {
        await outbox.recordRetry(row.id, lastError: e.toString());
      }
      return FlushReport(
        sent: batch.length,
        accepted: 0,
        duplicates: 0,
        rejected: 0,
        retriable: batch.length,
        lastError: e.toString(),
      );
    }
  }
}
