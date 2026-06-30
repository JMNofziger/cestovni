import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/settings_repository.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';
import 'debug_page.dart';
import 'vehicle_form_page.dart';

/// Settings — pushed route from the shell header gear icon (CES-56).
///
/// CES-39 phase 2 wires the vehicle CRUD section: add / edit / delete.
/// CES-57 wires the Preferences section (units / currency / timezone /
/// default vehicle) to [SettingsRepository]. Debug stays reachable
/// from inside Settings until the rollback tooling lands (CES-50).
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
          _PreferencesSection(db: db),
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

/// Preferences section (CES-57): distance/volume unit, currency,
/// timezone, and default vehicle — all wired to [SettingsRepository].
class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final settingsRepo = SettingsRepository(db);
    // Memoized once per `_PreferencesSection.build()` call (not inside
    // the StreamBuilder callback below) so a settings update doesn't
    // tear down and recreate the live-vehicles subscription on every
    // emission — same rationale as `shell.dart`'s `_liveVehicles`.
    final liveVehicles = VehiclesRepository(db).watchLive();
    return StreamBuilder<SettingsRow?>(
      stream: settingsRepo.watchSingle(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null) {
          // First read on a fresh install: kick off the bootstrap row
          // write; `watchSingle()` re-emits once it lands.
          settingsRepo.getOrBootstrap();
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _ChoiceTile(
              icon: Icons.straighten,
              title: 'Distance unit',
              value: settings.preferredDistanceUnit,
              options: const ['km', 'mi'],
              optionLabel: (v) => v == 'km' ? 'Kilometers (km)' : 'Miles (mi)',
              onChanged: (v) =>
                  settingsRepo.update(preferredDistanceUnit: v),
            ),
            _ChoiceTile(
              icon: Icons.local_drink,
              title: 'Volume unit',
              value: settings.preferredVolumeUnit,
              options: const ['L', 'gal'],
              optionLabel: (v) => v == 'L' ? 'Liters (L)' : 'Gallons (gal)',
              onChanged: (v) => settingsRepo.update(preferredVolumeUnit: v),
            ),
            _TextEntryTile(
              icon: Icons.attach_money,
              title: 'Currency',
              value: settings.currencyCode,
              dialogTitle: 'Currency code',
              hint: 'EUR',
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              validator: _validateCurrencyCode,
              normalize: (s) => s.trim().toUpperCase(),
              onChanged: (v) => settingsRepo.update(currencyCode: v),
            ),
            _TextEntryTile(
              icon: Icons.schedule,
              title: 'Timezone',
              value: settings.timezone,
              dialogTitle: 'Timezone (IANA)',
              hint: 'Europe/Prague',
              maxLength: 64,
              validator: _validateTimezone,
              normalize: (s) => s.trim(),
              onChanged: (v) => settingsRepo.update(timezone: v),
            ),
            _DefaultVehicleTile(
              liveVehicles: liveVehicles,
              currentId: settings.defaultVehicleId,
              onChanged: (id) => settingsRepo.update(defaultVehicleId: id),
            ),
          ],
        );
      },
    );
  }

  static String? _validateCurrencyCode(String s) {
    final t = s.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(t)) {
      return 'Enter a 3-letter ISO-4217 code (e.g. EUR).';
    }
    return null;
  }

  static String? _validateTimezone(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 64) {
      return 'Enter a timezone name (1-64 characters).';
    }
    return null;
  }
}

/// Single-choice preference row — taps open a bottom-sheet picker.
/// Used for the small fixed enums (distance / volume unit) backed by
/// SQL CHECK constraints in `client/lib/db/tables/settings.dart`.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final String Function(String) optionLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(optionLabel(value)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final colors = context.cestovniColors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.paper,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const HairlineDivider(),
            for (final option in options)
              ListTile(
                title: Text(optionLabel(option)),
                trailing: option == value
                    ? Icon(Icons.check, color: colors.ink)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}

/// Free-text preference row (currency code, timezone) — taps open a
/// validated text-entry dialog. Used where the legal value set is too
/// large to enumerate in a picker.
class _TextEntryTile extends StatelessWidget {
  const _TextEntryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.dialogTitle,
    required this.hint,
    required this.maxLength,
    required this.validator,
    required this.normalize,
    required this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String title;
  final String value;
  final String dialogTitle;
  final String hint;
  final int maxLength;
  final String? Function(String) validator;
  final String Function(String) normalize;
  final TextCapitalization textCapitalization;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _edit(context),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _TextEntryDialog(
        title: dialogTitle,
        initialValue: value,
        hint: hint,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        validator: validator,
        normalize: normalize,
      ),
    );
    if (result != null && result != value) onChanged(result);
  }
}

/// Dialog content for [_TextEntryTile]. A dedicated `StatefulWidget` so
/// the `TextEditingController` is disposed by its own `dispose()` —
/// tied to the route's exit-animation lifecycle — instead of being
/// torn down by the caller the instant `showDialog` resolves, which
/// raced the still-animating route and corrupted the element tree
/// ("TextEditingController was used after being disposed").
class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.maxLength,
    required this.textCapitalization,
    required this.validator,
    required this.normalize,
  });

  final String title;
  final String initialValue;
  final String hint;
  final int maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String) validator;
  final String Function(String) normalize;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: widget.textCapitalization,
          decoration: InputDecoration(hintText: widget.hint),
          validator: (v) => widget.validator(v ?? ''),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(widget.normalize(_controller.text));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Default-vehicle picker (CES-57) — bottom sheet over live vehicles
/// plus a "None" option to clear `settings.default_vehicle_id`.
class _DefaultVehicleTile extends StatelessWidget {
  const _DefaultVehicleTile({
    required this.liveVehicles,
    required this.currentId,
    required this.onChanged,
  });

  final Stream<List<VehicleRow>> liveVehicles;
  final String? currentId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehicleRow>>(
      stream: liveVehicles,
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? const <VehicleRow>[];
        VehicleRow? current;
        for (final v in vehicles) {
          if (v.id == currentId) {
            current = v;
            break;
          }
        }
        return ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('Default vehicle'),
          subtitle: Text(current?.name ?? 'None — first vehicle wins'),
          trailing: const Icon(Icons.chevron_right),
          onTap: vehicles.isEmpty ? null : () => _pick(context, vehicles),
        );
      },
    );
  }

  /// Distinguishes "explicitly chose None" from "dismissed the sheet
  /// without choosing" — both `Navigator.pop()` (no value) and a
  /// barrier dismiss otherwise resolve to the same `null` future, which
  /// would be indistinguishable from a deliberate clear-to-None pick.
  static const Object _noneOption = Object();

  Future<void> _pick(BuildContext context, List<VehicleRow> vehicles) async {
    final colors = context.cestovniColors;
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: colors.paper,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
              child: Text(
                'Default vehicle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const HairlineDivider(),
            ListTile(
              title: const Text('None — first vehicle wins'),
              trailing: currentId == null
                  ? Icon(Icons.check, color: colors.ink)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(_noneOption),
            ),
            for (final v in vehicles)
              ListTile(
                title: Text(v.name),
                trailing: v.id == currentId
                    ? Icon(Icons.check, color: colors.ink)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(v.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return; // dismissed without choosing
    final newId = identical(picked, _noneOption) ? null : picked as String;
    if (newId != currentId) onChanged(newId);
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
