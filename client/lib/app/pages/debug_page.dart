import 'package:drift/drift.dart' show Migrator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/outbox_repository.dart';
import '../../sync/outbox_flush_worker.dart';
import '../../sync/sync_client.dart';
import '../../sync/sync_config.dart';

/// Debug tab — exposes schema version, migration step names, an
/// integrity check, and (CES-44 gate slice) a **Sync now** button that
/// flushes the local outbox against the configured dev sync stub.
class DebugPage extends StatefulWidget {
  const DebugPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  String _status = '';
  String _syncStatus = '';
  int? _pendingCount;
  bool _syncing = false;

  late final OutboxRepository _outbox =
      OutboxRepository(widget.db);

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final count = await _outbox.pendingCount();
    if (!mounted) return;
    setState(() => _pendingCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.db.migrationRunner.steps;
    const cfg = SyncConfig.fromEnvironment;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Schema version', style: Theme.of(context).textTheme.titleMedium),
        Text('${widget.db.schemaVersion}'),
        const SizedBox(height: 16),
        Text('Migration steps', style: Theme.of(context).textTheme.titleMedium),
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${s.name}: v${s.from} → v${s.to}'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _runIntegrityCheck,
          child: const Text('Run PRAGMA integrity_check'),
        ),
        const SizedBox(height: 12),
        if (_status.isNotEmpty) Text(_status),
        const Divider(height: 32),
        Text('Sync (M3 gate slice)',
            style: Theme.of(context).textTheme.titleMedium),
        Text(
          cfg.isConfigured
              ? 'Target: ${cfg.baseUrl}'
              : 'Not configured — pass '
                  '--dart-define=CESTOVNI_SYNC_URL=… and '
                  '--dart-define=CESTOVNI_SYNC_TOKEN=… at launch.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Outbox pending: ${_pendingCount ?? '…'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed:
                  cfg.isConfigured && !_syncing ? _flushOutbox : null,
              child: Text(_syncing ? 'Syncing…' : 'Sync now'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _refreshPendingCount,
              child: const Text('Refresh count'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_syncStatus.isNotEmpty) Text(_syncStatus),
      ],
    );
  }

  Future<void> _runIntegrityCheck() async {
    try {
      final rows = await widget.db.customSelect('PRAGMA integrity_check').get();
      if (!mounted) return;
      setState(() {
        _status = rows.map((r) => r.data.values.first).join('\n');
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('integrity_check failed: $e\n$st');
      }
      if (!mounted) return;
      setState(() => _status = 'error: $e');
    }
  }

  Future<void> _flushOutbox() async {
    const cfg = SyncConfig.fromEnvironment;
    if (!cfg.isConfigured) return;
    setState(() {
      _syncing = true;
      _syncStatus = '…';
    });
    final client = SyncClient(
      baseUrl: cfg.baseUrl,
      bearerToken: cfg.bearerToken,
    );
    final worker = OutboxFlushWorker(outbox: _outbox, client: client);
    try {
      final report = await worker.flushOnce();
      if (!mounted) return;
      setState(() {
        _syncStatus = report.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncStatus = 'sync error: $e');
    } finally {
      client.close();
      if (mounted) {
        setState(() => _syncing = false);
      }
      await _refreshPendingCount();
    }
  }
}

/// Unused import-suppression helper to keep `Migrator` visible to
/// `dartanalyzer` — the import signals intent for upcoming CES-47
/// rollback controls that will render the migration API here.
// ignore: unused_element
void _keepMigratorVisible(Migrator _) {}
