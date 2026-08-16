import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/maintenance_events_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../../maintenance/performed_at.dart';
import '../../units/display_units.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Maintenance** tab — entry form + recent events (CES-67).
///
/// Spec: `cestovni-views.md` §Maintenance + `DATA_CONTRACTS.md`
/// §Maintenance entry contract. Date-only `performed_at` uses the
/// local-noon UTC encoding. Reminder fields persist on
/// `maintenance_rules`; scheduling UX is out of scope.
class MaintenancePage extends StatefulWidget {
  const MaintenancePage({
    super.key,
    required this.db,
    required this.onOpenSettings,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  late final MaintenanceEventsRepository _repo;
  late final SettingsRepository _settingsRepo;

  SettingsRow? _settings;
  StreamSubscription<SettingsRow?>? _settingsSub;

  final _odometerCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _remindDistanceCtrl = TextEditingController();
  final _remindMonthsCtrl = TextEditingController();

  DateTime _civilDate = DateTime.now();
  String _category = 'oil';
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _repo = MaintenanceEventsRepository(widget.db);
    _settingsRepo = SettingsRepository(widget.db);
    _settingsRepo.getOrBootstrap();
    _settingsSub = _settingsRepo.watchSingle().listen((row) {
      if (mounted && row != null) setState(() => _settings = row);
    });
  }

  String? _trackedVehicleId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vehicleId = ActiveVehicleScope.of(context).vehicleId;
    if (vehicleId != _trackedVehicleId) {
      _trackedVehicleId = vehicleId;
      if (vehicleId != null) _loadRule(vehicleId);
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _odometerCtrl.dispose();
    _shopCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _remindDistanceCtrl.dispose();
    _remindMonthsCtrl.dispose();
    super.dispose();
  }

  String get _distanceUnit => _settings?.preferredDistanceUnit ?? 'km';
  String get _currencyCode => _settings?.currencyCode ?? 'EUR';
  Duration get _tzOffset =>
      tzOffsetForSettings(_settings?.timezone ?? 'UTC');

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final vehicleId = ActiveVehicleScope.of(context).vehicleId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CestovniMetrics.pagePadding,
            CestovniMetrics.pagePadding,
            CestovniMetrics.pagePadding,
            0,
          ),
          child: Text('Maintenance',
              style: Theme.of(context).textTheme.headlineLarge),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: vehicleId == null
              ? _noVehicle(context, colors)
              : _body(vehicleId, colors),
        ),
      ],
    );
  }

  Widget _noVehicle(BuildContext context, CestovniColors colors) {
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: CestovniMetrics.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
          child: LedgerCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No vehicles yet',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Add your first vehicle to log maintenance.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onOpenSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.paper,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(CestovniMetrics.radiusBase),
                    ),
                  ),
                  child: Text(
                    'GO TO SETTINGS',
                    style: CestovniTypography.mono(
                      fontSize: 12,
                      color: colors.paper,
                      weight: FontWeight.w600,
                      letterSpacing: 0.12 * 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String vehicleId, CestovniColors colors) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: CestovniMetrics.pagePadding,
      ),
      children: [
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lbl('DATE', colors),
              const SizedBox(height: 6),
              _dateField(context, colors),
              const SizedBox(height: 16),
              _lbl('CATEGORY', colors),
              const SizedBox(height: 6),
              _categoryField(vehicleId, colors),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _txt(
                      'ODOMETER (${distanceUnitLabel(_distanceUnit)}) OPT.',
                      _odometerCtrl,
                      'odometer',
                      colors,
                      kb: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _txt(
                      'COST (${currencySymbol(_currencyCode).trim()}) OPT.',
                      _costCtrl,
                      'cost',
                      colors,
                      kb: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _txt('SHOP OPT.', _shopCtrl, 'shop', colors),
              const SizedBox(height: 16),
              _lbl('NOTES OPT.', colors),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                style: TextStyle(color: colors.ink),
                decoration: _deco(colors),
              ),
              const SizedBox(height: 16),
              Text(
                'REMIND IN (OPT.)',
                style: CestovniTypography.labelMono(
                    color: colors.mutedForeground),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _txt(
                      'DISTANCE (${distanceUnitLabel(_distanceUnit)})',
                      _remindDistanceCtrl,
                      'remindKm',
                      colors,
                      kb: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _txt(
                      'MONTHS',
                      _remindMonthsCtrl,
                      'remindMonths',
                      colors,
                      kb: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: CestovniMetrics.sectionGap),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _save(vehicleId),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.paper,
              disabledBackgroundColor: colors.rule,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(CestovniMetrics.radiusBase),
              ),
            ),
            child: Text(
              'SAVE ENTRY',
              style: CestovniTypography.mono(
                fontSize: 13,
                color: _saving ? colors.mutedForeground : colors.paper,
                weight: FontWeight.w600,
                letterSpacing: 0.12 * 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: CestovniMetrics.sectionGap),
        Text('RECENT',
            style: CestovniTypography.labelMono(color: colors.mutedForeground)),
        const SizedBox(height: 8),
        StreamBuilder<List<MaintenanceEventRow>>(
          stream: _repo.watchForVehicle(vehicleId),
          builder: (context, snap) {
            final rows = snap.data ?? const <MaintenanceEventRow>[];
            if (rows.isEmpty) {
              return Text(
                'No maintenance yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final row in rows.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentRow(
                      row: row,
                      distanceUnit: _distanceUnit,
                      tzOffset: _tzOffset,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: CestovniMetrics.pagePadding),
      ],
    );
  }

  Future<void> _loadRule(String vehicleId) async {
    final rule = await _repo.findRuleByVehicleAndName(vehicleId, _category);
    if (!mounted) return;
    if (rule == null) {
      _remindDistanceCtrl.clear();
      _remindMonthsCtrl.clear();
      return;
    }
    if (rule.cadenceKm != null) {
      _remindDistanceCtrl.text =
          metersToDisplayWhole(rule.cadenceKm!, _distanceUnit).toString();
    } else {
      _remindDistanceCtrl.clear();
    }
    if (rule.cadenceDays != null) {
      _remindMonthsCtrl.text =
          (rule.cadenceDays! / 30).round().clamp(1, 120).toString();
    } else {
      _remindMonthsCtrl.clear();
    }
  }

  Future<void> _save(String vehicleId) async {
    setState(() {
      _errors = {};
      _saving = true;
    });

    final errors = <String, String>{};
    final odoText = _odometerCtrl.text.trim();
    int? odometerM;
    if (odoText.isNotEmpty) {
      final odoVal = double.tryParse(odoText);
      if (odoVal == null || odoVal < 0) {
        errors['odometer'] = 'Must be a non-negative number';
      } else {
        odometerM = distanceToMeters(odoVal, _distanceUnit);
      }
    }

    final costText = _costCtrl.text.trim();
    var costCents = 0;
    if (costText.isNotEmpty) {
      final costVal = double.tryParse(costText);
      if (costVal == null || costVal < 0) {
        errors['cost'] = 'Must be a non-negative number';
      } else {
        costCents = majorToCents(costVal);
      }
    }

    final shop = _shopCtrl.text.trim();
    if (shop.length > 120) errors['shop'] = 'Max 120 characters';

    int? cadenceMeters;
    int? cadenceDays;
    final distText = _remindDistanceCtrl.text.trim();
    if (distText.isNotEmpty) {
      final distVal = double.tryParse(distText);
      if (distVal == null || distVal <= 0) {
        errors['remindKm'] = 'Must be greater than 0';
      } else {
        cadenceMeters = distanceToMeters(distVal, _distanceUnit);
      }
    }
    final monthsText = _remindMonthsCtrl.text.trim();
    if (monthsText.isNotEmpty) {
      final months = int.tryParse(monthsText);
      if (months == null || months <= 0) {
        errors['remindMonths'] = 'Must be a whole number > 0';
      } else {
        cadenceDays = months * 30;
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _saving = false;
      });
      return;
    }

    String? ruleId;
    if (cadenceMeters != null || cadenceDays != null) {
      ruleId = await _repo.upsertReminderRule(
        MaintenanceRuleDraft(
          vehicleId: vehicleId,
          name: _category,
          cadenceKmMeters: cadenceMeters,
          cadenceDays: cadenceDays,
        ),
      );
    }

    await _repo.create(
      MaintenanceEventDraft(
        vehicleId: vehicleId,
        performedAt: dateOnlyToPerformedAtUtc(_civilDate, tzOffset: _tzOffset),
        category: _category,
        costCents: costCents,
        currencyCode: _currencyCode,
        odometerM: odometerM,
        shop: shop.isEmpty ? null : shop,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ruleId: ruleId,
      ),
    );

    if (!mounted) return;
    _odometerCtrl.clear();
    _shopCtrl.clear();
    _costCtrl.clear();
    _notesCtrl.clear();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenance saved')),
    );
  }

  Widget _categoryField(String vehicleId, CestovniColors colors) {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      items: [
        for (final c in maintenanceCategories)
          DropdownMenuItem(
            value: c,
            child: Text(maintenanceCategoryLabel(c)),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _category = v);
        _loadRule(vehicleId);
      },
      decoration: _deco(colors),
      dropdownColor: colors.card,
      style: TextStyle(color: colors.ink, fontSize: 16),
    );
  }

  Widget _dateField(BuildContext context, CestovniColors colors) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime(_civilDate.year, _civilDate.month, _civilDate.day),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (date == null || !context.mounted) return;
        setState(() => _civilDate = date);
      },
      child: InputDecorator(
        decoration: _deco(colors),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fmtDate(_civilDate),
                style: CestovniTypography.mono(fontSize: 14, color: colors.ink),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 18, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _lbl(String t, CestovniColors c) =>
      Text(t, style: CestovniTypography.labelMono(color: c.mutedForeground));

  Widget _err(String t, CestovniColors c) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t, style: TextStyle(color: c.destructive, fontSize: 12)));

  Widget _txt(
    String label,
    TextEditingController ctrl,
    String errKey,
    CestovniColors c, {
    TextInputType kb = TextInputType.text,
  }) {
    final error = _errors[errKey];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl(label, c),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: kb,
          style: TextStyle(color: c.ink, fontSize: 16),
          decoration: _deco(c, error: error),
        ),
        if (error != null) _err(error, c),
      ],
    );
  }

  InputDecoration _deco(CestovniColors c, {String? error}) {
    final bc = error != null ? c.destructive : c.ink;
    return InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: c.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: bc, width: CestovniMetrics.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: bc, width: CestovniMetrics.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: c.ink, width: 2),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.row,
    required this.distanceUnit,
    required this.tzOffset,
  });

  final MaintenanceEventRow row;
  final String distanceUnit;
  final Duration tzOffset;

  @override
  Widget build(BuildContext context) {
    final civil = performedAtUtcToCivilDate(
      DateTime.parse(row.performedAt).toUtc(),
      tzOffset: tzOffset,
    );
    final cost = row.costCents == 0
        ? '—'
        : formatMoney(row.costCents, row.currencyCode);
    final odo = row.odometerM == null
        ? ''
        : '  ${formatDistance(row.odometerM!, distanceUnit)}';
    return LedgerTile(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_MaintenancePageState._fmtDate(civil)}  '
              '${maintenanceCategoryLabel(row.category)}$odo',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(cost, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
