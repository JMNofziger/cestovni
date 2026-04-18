import 'package:drift/drift.dart' show Migrator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../db/app_database.dart';

/// Debug tab — exposes schema version, migration step names, and a
/// button to force-create indexes. Handy during M0 bring-up and the
/// hook M5 (CES-47) rollback tooling will build on.
class DebugPage extends StatefulWidget {
  const DebugPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final steps = widget.db.migrationRunner.steps;
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
}

/// Unused import-suppression helper to keep `Migrator` visible to
/// `dartanalyzer` — the import signals intent for upcoming CES-47
/// rollback controls that will render the migration API here.
// ignore: unused_element
void _keepMigratorVisible(Migrator _) {}
