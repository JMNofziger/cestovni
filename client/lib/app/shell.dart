import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_database.dart';
import 'active_vehicle.dart';
import 'pages/history_page.dart';
import 'pages/log_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/metrics_page.dart';
import 'pages/settings_page.dart';
import 'theme/cestovni_primitives.dart';
import 'theme/cestovni_theme.dart';
import 'theme/cestovni_tokens.dart';
import 'theme/cestovni_typography.dart';

/// Bottom-nav shell with the M1 target tabs (Log / History / Metrics
/// / Maint), shared header, and active-vehicle selector.
///
/// CES-56 acceptance:
/// - Four bottom tabs match `cestovni-views.md` § *Shared chrome*.
/// - Header carries brand, current date, vehicle selector, theme
///   toggle, and a gear icon that pushes [SettingsPage] (Settings is
///   no longer a bottom tab).
/// - Debug stays accessible from inside Settings (per CES-50 — keep
///   the migration debug surface reachable until rollback tooling
///   replaces it).
class CestovniShell extends StatefulWidget {
  const CestovniShell({super.key, required this.db});

  final AppDatabase db;

  @override
  State<CestovniShell> createState() => _CestovniShellState();
}

class _CestovniShellState extends State<CestovniShell> {
  late final VehicleRepository _vehicles;
  late final ActiveVehicle _activeVehicle;
  late final Stream<List<VehicleRow>> _liveVehicles;
  int _index = 0;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _vehicles = VehicleRepository(widget.db);
    _activeVehicle = ActiveVehicle();
    // `watchLiveVehicles()` returns a new stream on every call;
    // memoize once so the StreamBuilder below is not re-subscribed on
    // every rebuild (which would loop with the active-vehicle
    // notifier below).
    _liveVehicles = _vehicles.watchLiveVehicles();
    _seedActiveVehicle();
  }

  Future<void> _seedActiveVehicle() async {
    final live = await _vehicles.liveVehiclesOnce();
    if (!mounted || live.isEmpty) return;
    _activeVehicle.setVehicleId(live.first.id);
  }

  @override
  void dispose() {
    _activeVehicle.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Local theme override so the toggle in the header flips the
    // shell + descendants without rebuilding `MaterialApp`.
    final theme = _themeMode == ThemeMode.dark
        ? CestovniTheme.dark()
        : CestovniTheme.light();

    return Theme(
      data: theme,
      child: ActiveVehicleScope(
        notifier: _activeVehicle,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _themeMode == ThemeMode.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Builder(
            builder: (innerContext) => Scaffold(
              backgroundColor: innerContext.cestovniColors.paper,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _ShellHeader(
                      liveVehicles: _liveVehicles,
                      onToggleTheme: _toggleTheme,
                      themeMode: _themeMode,
                      onOpenSettings: () => _openSettings(innerContext),
                    ),
                    const HairlineDivider(),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: const [
                          LogPage(),
                          HistoryPage(),
                          MetricsPage(),
                          MaintenancePage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _ShellBottomNav(
                index: _index,
                onChanged: (i) => setState(() => _index = i),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: _themeMode == ThemeMode.dark
              ? CestovniTheme.dark()
              : CestovniTheme.light(),
          child: SettingsPage(db: widget.db),
        ),
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.liveVehicles,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onOpenSettings,
  });

  final Stream<List<VehicleRow>> liveVehicles;
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final textTheme = Theme.of(context).textTheme;
    final today = _formatDate(DateTime.now());

    return Container(
      color: colors.paper,
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        12,
        CestovniMetrics.pagePadding,
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cestovni',
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  today.toUpperCase(),
                  style: CestovniTypography.labelMono(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _VehicleSelector(liveVehicles: liveVehicles),
          const SizedBox(width: 8),
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: onToggleTheme,
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colors.ink,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: Icon(Icons.settings_outlined, color: colors.ink),
          ),
        ],
      ),
    );
  }

  /// Lightweight `YYYY-MM-DD` formatter so we don't pull in
  /// `intl` for one label.
  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({required this.liveVehicles});

  final Stream<List<VehicleRow>> liveVehicles;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final active = ActiveVehicleScope.of(context);

    return StreamBuilder<List<VehicleRow>>(
      stream: liveVehicles,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <VehicleRow>[];

        // Drop stale active id if a vehicle disappeared between
        // session events; pick the first live vehicle as fallback.
        // Scheduled post-frame so we never call setState during a
        // build pass.
        if (list.isNotEmpty &&
            (active.vehicleId == null ||
                !list.any((v) => v.id == active.vehicleId))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            active.setVehicleId(list.first.id);
          });
        }

        if (list.isEmpty) {
          return _SelectorChip(
            label: 'NO VEHICLE',
            onTap: null,
            colors: colors,
          );
        }

        final current = list.firstWhere(
          (v) => v.id == active.vehicleId,
          orElse: () => list.first,
        );

        return _SelectorChip(
          label: current.name.toUpperCase(),
          colors: colors,
          onTap: list.length <= 1
              ? null
              : () => _showPicker(context, list, active, current),
        );
      },
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    List<VehicleRow> vehicles,
    ActiveVehicle active,
    VehicleRow current,
  ) async {
    final colors = context.cestovniColors;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.paper,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
                child: Text(
                  'Vehicle',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const HairlineDivider(),
              for (final v in vehicles)
                ListTile(
                  title: Text(v.name),
                  trailing: v.id == current.id
                      ? Icon(Icons.check, color: colors.ink)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(v.id),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) active.setVehicleId(picked);
  }
}

class _SelectorChip extends StatelessWidget {
  const _SelectorChip({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final CestovniColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CestovniMetrics.radiusBase);
    final disabled = onTap == null;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.paperDeep,
            border: Border.all(
              color: colors.ink,
              width: CestovniMetrics.hairline,
            ),
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: CestovniTypography.mono(
                  fontSize: 12,
                  color: disabled ? colors.mutedForeground : colors.ink,
                  weight: FontWeight.w600,
                  letterSpacing: 0.10 * 12,
                ),
              ),
              if (!disabled) ...[
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: colors.ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellBottomNav extends StatelessWidget {
  const _ShellBottomNav({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.cestovniColors.rule,
            width: CestovniMetrics.hairline,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'LOG',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'HISTORY',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'METRICS',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'MAINT.',
          ),
        ],
      ),
    );
  }
}

