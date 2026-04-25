import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';
import 'debug_page.dart';
import 'vehicle_form_page.dart';

/// Settings — pushed route from the shell header gear icon (CES-56).
///
/// CES-39 phase 2 wires the vehicle CRUD section: add / edit / delete.
/// Other preferences (units / currency / timezone / default vehicle)
/// are still placeholders pending a settings DAO + the
/// `default_vehicle_id` column (CES-57). Debug stays reachable from
/// inside Settings until the rollback tooling lands (CES-50).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: CestovniMetrics.tilePadding,
        ),
        children: [
          const _SectionLabel(text: 'Vehicles'),
          _VehiclesSection(db: db),
          const HairlineDivider(),
          const _SectionLabel(text: 'Preferences'),
          const ListTile(
            leading: Icon(Icons.straighten),
            title: Text('Distance unit'),
            subtitle: Text('km (default — wiring lands with CES-49)'),
          ),
          const ListTile(
            leading: Icon(Icons.local_drink),
            title: Text('Volume unit'),
            subtitle: Text('L (default — wiring lands with CES-49)'),
          ),
          const ListTile(
            leading: Icon(Icons.attach_money),
            title: Text('Currency'),
            subtitle: Text('EUR (default — wiring lands with CES-49)'),
          ),
          const ListTile(
            leading: Icon(Icons.schedule),
            title: Text('Timezone'),
            subtitle: Text('UTC (default — wiring lands with CES-49)'),
          ),
          const HairlineDivider(),
          const _SectionLabel(text: 'Backup'),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Backup'),
            subtitle: Text('Offline — sign in lands in M3.'),
          ),
          const HairlineDivider(),
          const _SectionLabel(text: 'Developer'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug'),
            subtitle: const Text(
              'Schema + migration tooling. Pre-rollback (CES-47).',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DebugPage(db: db),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vehicle list + add/edit/delete affordances. Lives inside Settings
/// so the existing route from the shell gear icon doubles as the
/// vehicle-management entry point. Archive/unarchive UX is deferred
/// to **CES-59**; v1 ships delete-only.
class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final repo = VehiclesRepository(db);
    return StreamBuilder<List<VehicleRow>>(
      stream: repo.watchLive(),
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? const <VehicleRow>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  CestovniMetrics.pagePadding,
                  4,
                  CestovniMetrics.pagePadding,
                  CestovniMetrics.tilePadding,
                ),
                child: Text(
                  'No vehicles yet. Add one to start logging fill-ups.',
                ),
              )
            else
              for (final v in vehicles)
                _VehicleRow(
                  db: db,
                  vehicle: v,
                  isLast: v == vehicles.last,
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CestovniMetrics.pagePadding,
                CestovniMetrics.tilePadding,
                CestovniMetrics.pagePadding,
                CestovniMetrics.tilePadding,
              ),
              child: OutlinedButton.icon(
                onPressed: () => _openVehicleForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openVehicleForm(BuildContext context) async {
    final newId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => VehicleFormPage(db: db),
      ),
    );
    if (newId == null || !context.mounted) return;
    final active = ActiveVehicleScope.of(context);
    if (active.vehicleId == null) {
      active.setVehicleId(newId);
    }
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.db,
    required this.vehicle,
    required this.isLast,
  });

  final AppDatabase db;
  final VehicleRow vehicle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(vehicle);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.directions_car_outlined),
          title: Text(vehicle.name),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(context),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context),
              ),
            ],
          ),
          onTap: () => _edit(context),
        ),
        if (!isLast) const HairlineDivider(indent: CestovniMetrics.pagePadding),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => VehicleFormPage(db: db, existing: vehicle),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete ${vehicle.name}?'),
        content: const Text(
          'Fill-up history will be preserved but the vehicle will not be '
          'selectable for new entries. This cannot be undone from the UI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = VehiclesRepository(db);
    final ok = await repo.softDelete(vehicle.id);
    if (!ok || !context.mounted) return;
    final active = ActiveVehicleScope.of(context);
    if (active.vehicleId == vehicle.id) {
      active.setVehicleId(null);
    }
  }

  static String? _subtitleFor(VehicleRow v) {
    final fuel = _fuelLabel(v.fuelType);
    final extras = <String>[];
    if (v.year != null) extras.add(v.year.toString());
    if (v.make != null) extras.add(v.make!);
    if (v.model != null) extras.add(v.model!);
    if (extras.isEmpty) return fuel;
    return '$fuel · ${extras.join(' ')}';
  }

  static String _fuelLabel(String wire) {
    switch (wire) {
      case 'gasoline':
        return 'Gasoline';
      case 'diesel':
        return 'Diesel';
      case 'lpg':
        return 'LPG';
      case 'cng':
        return 'CNG';
      case 'ev_kwh':
        return 'Electric';
      case 'other':
      default:
        return 'Other';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        CestovniMetrics.tilePadding,
        CestovniMetrics.pagePadding,
        4,
      ),
      child: Text(
        text.toUpperCase(),
        style: CestovniTypography.labelMono(
          color: context.cestovniColors.mutedForeground,
        ),
      ),
    );
  }
}
