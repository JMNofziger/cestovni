import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/outbox_repository.dart';
import '../../sync/dead_letter_summary.dart';
import '../../sync/outbox_flush_worker.dart';
import '../../sync/restore_service.dart';
import '../../sync/sync_client.dart';
import '../../sync/sync_config.dart';
import '../restore_scope.dart';
import '../theme/cestovni_tokens.dart';
import 'restore_progress_page.dart';

/// Settings → Backup. Dead-letter rows, discarded inserts, and restore.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key, required this.db});

  final AppDatabase db;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  late final OutboxRepository _outbox;
  late final Stream<List<OutboxRow>> _deadLetters;
  late final Stream<List<BackupMark>> _marks;

  @override
  void initState() {
    super.initState();
    _outbox = OutboxRepository(widget.db);
    _deadLetters = _outbox.watchDeadLetterRows();
    final marks = widget.db.select(widget.db.backupMarks)
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    _marks = marks.watch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<OutboxRow>>(
          stream: _deadLetters,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <OutboxRow>[];
            if (rows.isEmpty) {
              return const ListTile(
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Backup'),
                subtitle: Text('Nothing is waiting on a server rejection.'),
              );
            }
            return _DeadLetterCard(db: widget.db, rows: rows);
          },
        ),
        _NotBackedUpList(stream: _marks),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('Restore from backup'),
          subtitle: const Text(
            'Download vehicles, fill-ups, and maintenance from the server.',
          ),
          onTap: () => _confirmRestore(context),
        ),
      ],
    );
  }

  Future<void> _confirmRestore(BuildContext context) async {
    const cfg = SyncConfig.fromEnvironment;
    final controller = RestoreScope.maybeOf(context);
    if (!cfg.isConfigured && controller == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore from backup'),
          content: const Text(
            'Set CESTOVNI_SYNC_URL and CESTOVNI_SYNC_TOKEN to restore.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'The server copy replaces any row it already knows. '
          'Fill-ups you saved only on this device stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RestoreProgressPage(
          reason: RestoreReason.userInitiated,
        ),
      ),
    );
  }
}

class _DeadLetterCard extends StatelessWidget {
  const _DeadLetterCard({required this.db, required this.rows});

  final AppDatabase db;
  final List<OutboxRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final latest = rows.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        4,
        CestovniMetrics.pagePadding,
        8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.warn),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rows.length == 1
                    ? '1 change was not backed up'
                    : '${rows.length} changes were not backed up',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(deadLetterSummary(latest)),
              const SizedBox(height: 8),
              for (final row in rows) _DeadLetterTile(db: db, row: row),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeadLetterTile extends StatelessWidget {
  const _DeadLetterTile({required this.db, required this.row});

  final AppDatabase db;
  final OutboxRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        Text(deadLetterSummary(row)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              key: ValueKey('dead-letter-retry-${row.id}'),
              onPressed: () => _retry(context),
              child: const Text('Retry now'),
            ),
            TextButton(
              key: ValueKey('dead-letter-discard-${row.id}'),
              onPressed: () => _discard(context),
              child: const Text('Discard'),
            ),
            TextButton(
              key: ValueKey('dead-letter-details-${row.id}'),
              onPressed: () => _details(context),
              child: const Text('View details'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _retry(BuildContext context) async {
    final outbox = OutboxRepository(db);
    await outbox.retryDeadLetter(row.id);
    const cfg = SyncConfig.fromEnvironment;
    if (!cfg.isConfigured) return;
    final client = SyncClient(
      baseUrl: cfg.baseUrl,
      bearerToken: cfg.bearerToken,
    );
    try {
      await OutboxFlushWorker(outbox: outbox, client: client).flushOnce();
    } catch (_) {
      // The row is already re-queued. The foreground timer will try again.
    } finally {
      client.close();
    }
  }

  Future<void> _discard(BuildContext context) async {
    final insert = row.op == 'insert';
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this backup?'),
        content: Text(
          insert
              ? 'The outbox entry is removed. The local row stays on this '
                  'device and is marked not backed up.'
              : 'The outbox entry is removed. The local row stays on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await OutboxRepository(db).discardDeadLetter(row.id);
  }

  Future<void> _details(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup error'),
        content: SelectableText(row.lastError ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _NotBackedUpList extends StatelessWidget {
  const _NotBackedUpList({required this.stream});

  final Stream<List<BackupMark>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BackupMark>>(
      stream: stream,
      builder: (context, snapshot) {
        final marks = snapshot.data ?? const <BackupMark>[];
        if (marks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final mark in marks)
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(
                  '${backupTableLabel(mark.markedTable)} not backed up',
                ),
                subtitle: const Text('Kept on this device'),
              ),
          ],
        );
      },
    );
  }
}
