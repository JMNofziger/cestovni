/// Settings → Import data (CES-70).
///
/// Spec: `docs/specs/export-import.md` § UX. Sits directly under
/// **Export data** in the Backup section.
///
/// Flow: pick a `.zip` → validate with no writes → confirm dialog showing
/// what comes in and what goes out → apply → summary. Foreground-only,
/// matching export amendment A5.
///
/// User-facing wording comes from the spec's § User-facing explanation
/// rather than being invented here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/app_database.dart';
import '../../db/repositories/settings_repository.dart';
import '../../export/export_service.dart';
import '../../import/apply.dart';
import '../../import/import_errors.dart';
import '../../import/import_service.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

class ImportDataSection extends StatefulWidget {
  const ImportDataSection({super.key, required this.db, this.service});

  final AppDatabase db;

  /// Test hook. Production leaves this null and builds an
  /// [ImportService] that uses the platform picker.
  final ImportService? service;

  @override
  State<ImportDataSection> createState() => _ImportDataSectionState();
}

class _ImportDataSectionState extends State<ImportDataSection> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    if (_busy) return;
    final active = ActiveVehicleScope.of(context);
    final service = widget.service ?? ImportService(db: widget.db);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final Uint8List? bytes = await service.pickArchive();
      if (bytes == null) return;

      final preview = await service.preview(bytes);
      if (!mounted) return;

      final typed = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportConfirmDialog(db: widget.db, preview: preview),
      );
      if (typed == null || !mounted) return;

      final outcome = await service.commit(
        preview,
        typedConfirmation: typed,
      );

      await _reseedActiveVehicle(active);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => _ImportSummaryDialog(outcome: outcome),
      );
    } on ImportException catch (e) {
      if (mounted) setState(() => _error = e.display);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Import failed. Nothing was changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The previously active vehicle id may have been destroyed by the
  /// replace, so re-run the shell's seeding rule (CES-57: the persisted
  /// default wins when it resolves to a live vehicle).
  Future<void> _reseedActiveVehicle(ActiveVehicle active) async {
    final live = await VehiclesRepository(widget.db).liveOnce();
    if (live.isEmpty) {
      active.setVehicleId(null);
      return;
    }
    final settings = await SettingsRepository(widget.db).getOrBootstrap();
    final defaultId = settings.defaultVehicleId;
    final defaultIsLive =
        defaultId != null && live.any((v) => v.id == defaultId);
    active.setVehicleId(defaultIsLive ? defaultId : live.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        0,
        CestovniMetrics.pagePadding,
        CestovniMetrics.tilePadding,
      ),
      child: LedgerTile(
        onTap: _busy ? null : _run,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMPORT',
              style: CestovniTypography.labelMono(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Import data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Replaces this device's history with a backup file.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.destructive,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows what comes in and what goes out side by side, then gates the
/// destructive path behind a typed keyword.
class _ImportConfirmDialog extends StatefulWidget {
  const _ImportConfirmDialog({required this.db, required this.preview});

  final AppDatabase db;
  final ImportPreview preview;

  @override
  State<_ImportConfirmDialog> createState() => _ImportConfirmDialogState();
}

class _ImportConfirmDialogState extends State<_ImportConfirmDialog> {
  final _keywordController = TextEditingController();
  bool _exporting = false;
  String? _exportNote;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool get _confirmed {
    if (!widget.preview.requiresTypedConfirmation) return true;
    return _keywordController.text == importConfirmationKeyword;
  }

  Future<void> _exportFirst() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportNote = null;
    });
    try {
      await ExportService(db: widget.db).exportAndShare();
      if (mounted) setState(() => _exportNote = 'Current data exported.');
    } catch (_) {
      if (mounted) {
        setState(() => _exportNote = 'Export failed. Try again before '
            'importing.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final theme = Theme.of(context);
    final preview = widget.preview;
    final plan = preview.plan;
    final footprint = preview.footprint;
    final destructive = preview.requiresTypedConfirmation;

    return AlertDialog(
      title: Text(
        destructive
            ? "Replace this device's history?"
            : 'Import this backup?',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destructive
                  ? 'Importing is a restore, not a merge. This device will '
                      'match the backup exactly, and there is no undo.'
                  : 'This device has no records yet, so nothing will be '
                      'lost.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CountBlock(
              label: 'COMING IN',
              counts: plan.incomingCounts,
            ),
            if (destructive) ...[
              const SizedBox(height: 12),
              _CountBlock(
                label: 'BEING REPLACED',
                counts: footprint.rowCounts,
                emphasize: true,
              ),
            ],
            const SizedBox(height: 12),
            _MetaLine(
              label: 'Backup made',
              value: plan.manifest.exportedAtUtc,
            ),
            _MetaLine(
              label: 'Archive key',
              value: plan.manifest.userKeyHash,
            ),
            if (footprint.queuedChanges > 0)
              _MetaLine(
                label: 'Queued changes discarded',
                value: '${footprint.queuedChanges}',
              ),
            if (footprint.draftsAtRisk > 0)
              _MetaLine(
                label: 'Unsaved fill-ups discarded',
                value: '${footprint.draftsAtRisk}',
              ),
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final warning in preview.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    warning.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
            ],
            if (destructive) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _exporting ? null : _exportFirst,
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: const Text('Export current data first'),
              ),
              if (_exportNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _exportNote!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Type $importConfirmationKeyword to continue.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keywordController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    importConfirmationKeyword.length,
                  ),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirmed
              // The service only enforces the keyword when the preview
              // says it is required, so passing it unconditionally is
              // safe and keeps the dialog contract to a single String.
              ? () => Navigator.of(context).pop(importConfirmationKeyword)
              : null,
          child: Text(destructive ? 'Replace' : 'Import'),
        ),
      ],
    );
  }
}

class _ImportSummaryDialog extends StatelessWidget {
  const _ImportSummaryDialog({required this.outcome});

  final ImportOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Import complete'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CountBlock(label: 'WRITTEN', counts: outcome.rowsWritten),
            if (outcome.totalReplaced > 0) ...[
              const SizedBox(height: 12),
              _CountBlock(label: 'REPLACED', counts: outcome.rowsReplaced),
            ],
            const SizedBox(height: 12),
            if (outcome.queueDiscarded > 0)
              _MetaLine(
                label: 'Queued changes discarded',
                value: '${outcome.queueDiscarded}',
              ),
            if (outcome.draftsDiscarded > 0)
              _MetaLine(
                label: 'Unsaved fill-ups discarded',
                value: '${outcome.draftsDiscarded}',
              ),
            if (outcome.photoIdsToDelete.isNotEmpty)
              _MetaLine(
                label: 'Receipt photos removed',
                value: '${outcome.photoIdsToDelete.length}',
              ),
            const SizedBox(height: 8),
            Text(
              'Receipt photos are never part of a backup, so none were '
              'imported.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({
    required this.label,
    required this.counts,
    this.emphasize = false,
  });

  final String label;
  final Map<String, int> counts;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CestovniTypography.labelMono(
            color: emphasize ? colors.destructive : colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        for (final entry in counts.entries)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _humanTable(entry.key),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${entry.value}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _humanTable(String table) {
    switch (table) {
      case 'vehicles':
        return 'Vehicles';
      case 'fill_ups':
        return 'Fill-ups';
      case 'maintenance_rules':
        return 'Reminders';
      case 'maintenance_events':
        return 'Maintenance';
      case 'settings':
        return 'Preferences';
      default:
        return table;
    }
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
