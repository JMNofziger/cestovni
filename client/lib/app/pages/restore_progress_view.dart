import 'package:flutter/material.dart';

import '../theme/cestovni_tokens.dart';
import '../../sync/restore_service.dart';

/// Full-screen restore progress. The route pops once core tables are
/// caught up; background tables keep running on [RestoreController].
class RestoreProgressView extends StatelessWidget {
  const RestoreProgressView({
    super.key,
    required this.snapshot,
    required this.onRetry,
    required this.onUseOffline,
  });

  final RestoreSnapshot snapshot;
  final VoidCallback onRetry;
  final VoidCallback onUseOffline;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final failed = snapshot.phase == RestoreRunPhase.failed;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(title: const Text('Restore backup')),
      body: ListView(
        padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
        children: [
          Text(
            failed
                ? 'Restore stopped'
                : snapshot.phase == RestoreRunPhase.complete
                    ? 'Backup restored'
                    : 'Restoring your backup',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? (snapshot.message ?? 'The server could not be reached.')
                : 'You can log fill-ups once vehicles and fill-ups are here. '
                    'Maintenance keeps downloading after that.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final table in snapshot.tables) _TableLine(progress: table),
          if (snapshot.tables.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Waiting for the server…'),
            ),
          const SizedBox(height: 24),
          if (failed)
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onUseOffline,
            child: const Text('Use this device offline'),
          ),
        ],
      ),
    );
  }
}

class _TableLine extends StatelessWidget {
  const _TableLine({required this.progress});

  final RestoreTableProgress progress;

  @override
  Widget build(BuildContext context) {
    final label = _label(progress.table);
    final done = progress.phase == RestoreTablePhase.done;
    final waiting = progress.phase == RestoreTablePhase.waiting;
    final text = waiting
        ? '$label: waiting...'
        : done
            ? '$label: ${progress.received}/${progress.total} ✓'
            : '$label: ${progress.received}/${progress.total}...';
    final total = progress.total <= 0 ? 1.0 : progress.total.toDouble();
    final value = waiting
        ? 0.0
        : (progress.received / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: done ? 1 : value),
        ],
      ),
    );
  }

  static String _label(String table) {
    switch (table) {
      case 'vehicles':
        return 'Vehicles';
      case 'fill_ups':
        return 'Fill-ups';
      case 'maintenance_rules':
        return 'Maintenance rules';
      case 'maintenance_events':
        return 'Maintenance';
      case 'settings':
        return 'Settings';
      default:
        return table;
    }
  }
}
