import 'dart:async';

import 'package:flutter/material.dart';

import '../../consumption/adapters.dart';
import '../../consumption/models.dart';
import '../../consumption/validation.dart';
import '../../db/app_database.dart';
import '../../db/repositories/fill_ups_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../../units/display_units.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **History** tab — fuel-up timeline per `cestovni-views.md`.
///
/// CES-39: replaces M1 stub with a working fill-up list, month
/// grouping, detail sheet, amend, and soft-delete.
class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.db,
    required this.onOpenSettings,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum _Filter { all, fuel }

class _HistoryPageState extends State<HistoryPage> {
  late final FillUpsRepository _repo;
  late final SettingsRepository _settingsRepo;
  _Filter _filter = _Filter.all;

  /// Latest settings row (CES-65) — distance / volume display units
  /// follow these prefs. Money renders in each row's own stored
  /// currency, not the current pref. Defaults (km / L) apply until
  /// the bootstrap read lands.
  SettingsRow? _settings;
  StreamSubscription<SettingsRow?>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _repo = FillUpsRepository(widget.db);
    _settingsRepo = SettingsRepository(widget.db);
    _settingsRepo.getOrBootstrap();
    _settingsSub = _settingsRepo.watchSingle().listen((row) {
      if (mounted && row != null) setState(() => _settings = row);
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  String get _distanceUnit => _settings?.preferredDistanceUnit ?? 'km';
  String get _volumeUnit => _settings?.preferredVolumeUnit ?? 'L';

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
          child: Row(
            children: [
              Expanded(
                child: Text('History',
                    style: Theme.of(context).textTheme.headlineLarge),
              ),
              _viewToggle(colors),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: CestovniMetrics.pagePadding),
          child: _filterChips(colors),
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

  // ────────────────────────────── Header widgets

  Widget _viewToggle(CestovniColors colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.ink, width: CestovniMetrics.hairline),
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('TIMELINE', true, colors),
          _toggleBtn('FLIP', false, colors),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool isActive, CestovniColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? colors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusSm),
      ),
      child: Text(
        label,
        style: CestovniTypography.mono(
          fontSize: 11,
          color: isActive ? colors.paper : colors.mutedForeground,
          weight: FontWeight.w600,
          letterSpacing: 0.08 * 11,
        ),
      ),
    );
  }

  Widget _filterChips(CestovniColors colors) {
    return Row(
      children: [
        _chip('ALL', _filter == _Filter.all, colors,
            () => setState(() => _filter = _Filter.all)),
        const SizedBox(width: 8),
        _chip('FUEL', _filter == _Filter.fuel, colors,
            () => setState(() => _filter = _Filter.fuel)),
        const SizedBox(width: 8),
        _chip('MAINT', false, colors, null, disabled: true),
      ],
    );
  }

  Widget _chip(String label, bool selected, CestovniColors colors,
      VoidCallback? onTap,
      {bool disabled = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.ink : Colors.transparent,
          border:
              Border.all(color: colors.ink, width: CestovniMetrics.hairline),
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        ),
        child: Text(
          label,
          style: CestovniTypography.mono(
            fontSize: 11,
            color: disabled
                ? colors.mutedForeground.withValues(alpha: 0.4)
                : selected
                    ? colors.paper
                    : colors.ink,
            weight: FontWeight.w500,
            letterSpacing: 0.08 * 11,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Body

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
                  'Add your first vehicle to start logging fuel-ups\nand maintenance.',
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
    return StreamBuilder<List<FillUpRow>>(
      stream: _repo.watchForVehicle(vehicleId),
      builder: (context, snap) {
        final rows = snap.data ?? const <FillUpRow>[];

        if (rows.isEmpty) {
          return _emptyFillUps(context, colors);
        }

        final grouped = _groupByMonth(rows);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: CestovniMetrics.pagePadding),
          itemCount: grouped.length,
          itemBuilder: (context, i) => grouped[i],
        );
      },
    );
  }

  Widget _emptyFillUps(BuildContext context, CestovniColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
        child: LedgerCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_gas_station_outlined,
                  size: 32, color: colors.ink),
              const SizedBox(height: 12),
              Text('No fill-ups yet',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Go to the Log tab to record your first fuel-up.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Month grouping

  List<Widget> _groupByMonth(List<FillUpRow> rows) {
    final widgets = <Widget>[];
    String? currentGroup;

    for (final row in rows) {
      final dt = DateTime.parse(row.filledAt).toLocal();
      final groupKey = '${dt.year}-${dt.month}';
      if (groupKey != currentGroup) {
        final count =
            rows.where((r) {
              final rd = DateTime.parse(r.filledAt).toLocal();
              return rd.year == dt.year && rd.month == dt.month;
            }).length;
        widgets.add(_monthHeader(dt, count));
        currentGroup = groupKey;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _FillUpCard(
          row: row,
          distanceUnit: _distanceUnit,
          volumeUnit: _volumeUnit,
          onTap: () => _showDetail(row),
        ),
      ));
    }
    return widgets;
  }

  Widget _monthHeader(DateTime dt, int count) {
    final colors = context.cestovniColors;
    final month = _monthName(dt.month);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text('$month ${dt.year}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Expanded(child: HairlineDivider()),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'ENTRY' : 'ENTRIES'}',
            style:
                CestovniTypography.labelMono(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── Detail sheet

  void _showDetail(FillUpRow row) {
    final colors = context.cestovniColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.paper,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        row: row,
        colors: colors,
        distanceUnit: _distanceUnit,
        volumeUnit: _volumeUnit,
        onDelete: () => _confirmDelete(row),
        onEdit: () => _openEdit(row),
      ),
    );
  }

  Future<void> _confirmDelete(FillUpRow row) async {
    Navigator.of(context).pop(); // close sheet
    final colors = context.cestovniColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.paper,
        title: Text('Delete entry?',
            style: TextStyle(color: colors.ink)),
        content: Text(
          'This fill-up will be removed from your history.',
          style: TextStyle(color: colors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Delete', style: TextStyle(color: colors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.softDelete(row.id);
    }
  }

  void _openEdit(FillUpRow row) {
    Navigator.of(context).pop(); // close sheet
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: Theme.of(context),
          child: ActiveVehicleScope(
            notifier: ActiveVehicleScope.of(context),
            child: _FillUpEditPage(
              db: widget.db,
              existing: row,
              distanceUnit: _distanceUnit,
              volumeUnit: _volumeUnit,
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Formatting helpers

  static String _monthName(int m) => const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][m];
}

// ══════════════════════════════════════════════════════════════════════
// Fill-up row card (matches history screenshot timeline row).
// ══════════════════════════════════════════════════════════════════════

class _FillUpCard extends StatelessWidget {
  const _FillUpCard({
    required this.row,
    required this.distanceUnit,
    required this.volumeUnit,
    required this.onTap,
  });

  final FillUpRow row;
  final String distanceUnit;
  final String volumeUnit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final dt = DateTime.parse(row.filledAt).toLocal();

    return LedgerCard(
      onTap: onTap,
      padding: const EdgeInsets.all(CestovniMetrics.tilePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.ink,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fmtShortDate(dt),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontStyle: FontStyle.normal),
                      ),
                    ),
                    Text(
                      formatMoney(row.totalPriceCents, row.currencyCode),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDistance(row.odometerM, distanceUnit)}     '
                  '${volumeToDisplay(row.volumeUL, volumeUnit)} $volumeUnit',
                  style: TextStyle(
                      color: colors.mutedForeground, fontSize: 13),
                ),
                const SizedBox(height: 6),
                _pill('FUEL', colors.ink, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color borderColor, CestovniColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
            color: borderColor, width: CestovniMetrics.hairline),
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusXs),
      ),
      child: Text(
        label,
        style: CestovniTypography.mono(
          fontSize: 10,
          color: colors.ink,
          weight: FontWeight.w600,
          letterSpacing: 0.08 * 10,
        ),
      ),
    );
  }

  static String _fmtShortDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month]} ${dt.day}';
  }

}

// ══════════════════════════════════════════════════════════════════════
// Detail bottom sheet (matches history-detail.png screenshot).
// ══════════════════════════════════════════════════════════════════════

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.row,
    required this.colors,
    required this.distanceUnit,
    required this.volumeUnit,
    required this.onDelete,
    required this.onEdit,
  });

  final FillUpRow row;
  final CestovniColors colors;
  final String distanceUnit;
  final String volumeUnit;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(row.filledAt).toLocal();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Fuel-up details',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.ink),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow('DATE', _fmtFull(dt)),
            _detailRow('ODOMETER (${distanceUnitLabel(distanceUnit)})',
                formatThousands(metersToDisplayWhole(
                    row.odometerM, distanceUnit))),
            _detailRow('VOLUME (${volumeUnitLabel(volumeUnit)})',
                volumeToDisplay(row.volumeUL, volumeUnit, decimals: 3)),
            _detailRow(
                'TOTAL', formatMoney(row.totalPriceCents, row.currencyCode)),
            _detailRow('PARTIAL', row.isFull ? 'No' : 'Yes'),
            if (row.notes != null && row.notes!.isNotEmpty)
              _detailRow('NOTES', row.notes!),
            if (row.missedBefore) _detailRow('MISSED BEFORE', 'Yes'),
            if (row.odometerReset) _detailRow('ODOMETER RESET', 'Yes'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, color: colors.ink),
                    label: Text('Edit entry',
                        style: TextStyle(color: colors.ink)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.ink),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CestovniMetrics.radiusBase),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: colors.paper),
                    label: Text('Delete entry',
                        style: TextStyle(color: colors.paper)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.destructive,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CestovniMetrics.radiusBase),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: CestovniTypography.labelMono(
                    color: colors.mutedForeground)),
          ),
          Text(value,
              style: TextStyle(color: colors.ink, fontSize: 14)),
        ],
      ),
    );
  }

  static String _fmtFull(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m/$d/${dt.year}, ${h.toString().padLeft(2, '0')}:$min:$sec $ampm';
  }
}

// ══════════════════════════════════════════════════════════════════════
// Fill-up edit page (amend existing row — pushed from detail sheet).
// ══════════════════════════════════════════════════════════════════════

class _FillUpEditPage extends StatefulWidget {
  const _FillUpEditPage({
    required this.db,
    required this.existing,
    required this.distanceUnit,
    required this.volumeUnit,
  });

  final AppDatabase db;
  final FillUpRow existing;
  final String distanceUnit;
  final String volumeUnit;

  @override
  State<_FillUpEditPage> createState() => _FillUpEditPageState();
}

class _FillUpEditPageState extends State<_FillUpEditPage> {
  late final FillUpsRepository _repo;
  late final TextEditingController _odometerCtrl;
  late final TextEditingController _volumeCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _filledAt;
  late bool _partialFill;
  late bool _missedBefore;
  late bool _odometerReset;
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _repo = FillUpsRepository(widget.db);
    final r = widget.existing;
    _filledAt = DateTime.parse(r.filledAt).toLocal();
    _odometerCtrl = TextEditingController(
        text: metersToDisplayWhole(r.odometerM, widget.distanceUnit)
            .toString());
    _volumeCtrl = TextEditingController(
        text: microlitersToDouble(r.volumeUL, widget.volumeUnit)
            .toStringAsFixed(3));
    _totalCtrl = TextEditingController(
        text: (r.totalPriceCents / 100).toStringAsFixed(2));
    _notesCtrl = TextEditingController(text: r.notes ?? '');
    _partialFill = !r.isFull;
    _missedBefore = r.missedBefore;
    _odometerReset = r.odometerReset;
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _volumeCtrl.dispose();
    _totalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errors = {};
      _saving = true;
    });

    final odometerVal = int.tryParse(_odometerCtrl.text.trim());
    final volumeVal = double.tryParse(_volumeCtrl.text.trim());
    final totalMajor = double.tryParse(_totalCtrl.text.trim());

    final errors = <String, String>{};
    if (odometerVal == null) errors['odometer'] = 'Required';
    if (volumeVal == null || volumeVal <= 0) errors['volume'] = 'Required';
    if (totalMajor == null || totalMajor <= 0) errors['total'] = 'Required';

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _saving = false;
      });
      return;
    }

    // Amend keeps the row's stored currency (a row logged in EUR stays
    // EUR even if prefs changed since); units follow current prefs.
    final odometerM =
        distanceToMeters(odometerVal!.toDouble(), widget.distanceUnit);
    final volumeUL = volumeToMicroliters(volumeVal!, widget.volumeUnit);
    final totalCents = majorToCents(totalMajor!);
    final notes = _notesCtrl.text.trim();

    final candidate = FillUp(
      id: widget.existing.id,
      vehicleId: widget.existing.vehicleId,
      filledAt: _filledAt.toUtc(),
      odometerM: odometerM,
      volumeUL: volumeUL,
      totalPriceCents: totalCents,
      currencyCode: widget.existing.currencyCode,
      isFull: !_partialFill,
      missedBefore: _missedBefore,
      odometerReset: _odometerReset,
      notes: notes.isEmpty ? null : notes,
    );

    final allRows =
        await _repo.listForVehicle(widget.existing.vehicleId);
    final existing = fillUpsFromRows(allRows)
        .where((f) => f.id != widget.existing.id)
        .toList();

    final failure =
        validateInsert(candidate, existing, DateTime.now().toUtc());
    if (failure != null) {
      setState(() {
        _errors = _mapError(failure);
        _saving = false;
      });
      return;
    }

    await _repo.amend(
      widget.existing.id,
      FillUpDraft(
        vehicleId: widget.existing.vehicleId,
        filledAt: _filledAt.toUtc(),
        odometerM: odometerM,
        volumeUL: volumeUL,
        totalPriceCents: totalCents,
        currencyCode: widget.existing.currencyCode,
        isFull: !_partialFill,
        missedBefore: _missedBefore,
        odometerReset: _odometerReset,
        notes: notes.isEmpty ? null : notes,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fill-up updated')),
    );
  }

  Map<String, String> _mapError(ValidationFailure f) {
    return switch (f.code) {
      ValidationErrorCode.odometerNegative => {
          'odometer': 'Cannot be negative'
        },
      ValidationErrorCode.volumeNegative => {'volume': 'Cannot be negative'},
      ValidationErrorCode.priceNegative => {'total': 'Cannot be negative'},
      ValidationErrorCode.filledAtInFuture => {
          'date': 'Cannot be more than 24 h in the future'
        },
      ValidationErrorCode.odometerRegression => {
          'odometer':
              'Must be higher than last reading (or enable Odometer Reset)'
        },
      ValidationErrorCode.resetOnFirstFillup => {
          'reset': 'Cannot reset odometer on the first fill-up'
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        title: Text('Edit Fill-Up',
            style: Theme.of(context).textTheme.headlineSmall),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: CestovniMetrics.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lbl('DATE & TIME', colors),
                      const SizedBox(height: 6),
                      _dateField(context, colors),
                      if (_errors.containsKey('date'))
                        _err(_errors['date']!, colors),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _txt(
                                  'ODOMETER (${distanceUnitLabel(widget.distanceUnit)})',
                                  _odometerCtrl,
                                  'odometer',
                                  colors,
                                  kb: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _txt(
                                  'VOLUME (${volumeUnitLabel(widget.volumeUnit)})',
                                  _volumeCtrl,
                                  'volume',
                                  colors,
                                  kb: const TextInputType.numberWithOptions(
                                      decimal: true))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _txt(
                          'TOTAL (${currencySymbol(widget.existing.currencyCode).trim()})',
                          _totalCtrl,
                          'total',
                          colors,
                          kb: const TextInputType.numberWithOptions(
                              decimal: true)),
                      const SizedBox(height: 16),
                      _toggle('PARTIAL FILL', 'Tank not filled to full',
                          _partialFill,
                          (v) => setState(() => _partialFill = v), colors),
                      const SizedBox(height: 8),
                      _toggle(
                          'MISSED BEFORE',
                          'Missed fill-ups before this one',
                          _missedBefore,
                          (v) => setState(() => _missedBefore = v),
                          colors),
                      const SizedBox(height: 8),
                      _toggle(
                          'ODOMETER RESET',
                          'Odometer was reset',
                          _odometerReset,
                          (v) => setState(() => _odometerReset = v),
                          colors),
                      if (_errors.containsKey('reset'))
                        _err(_errors['reset']!, colors),
                      const SizedBox(height: 16),
                      _lbl('NOTES (OPT.)', colors),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        style: TextStyle(color: colors.ink),
                        decoration: _deco(colors),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CestovniMetrics.sectionGap),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.ink,
                      foregroundColor: colors.paper,
                      disabledBackgroundColor: colors.rule,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            CestovniMetrics.radiusBase),
                      ),
                    ),
                    child: Text(
                      'UPDATE ENTRY',
                      style: CestovniTypography.mono(
                        fontSize: 13,
                        color:
                            _saving ? colors.mutedForeground : colors.paper,
                        weight: FontWeight.w600,
                        letterSpacing: 0.12 * 13,
                      ),
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

  // ── Shared field helpers (minimal — edit page only) ──

  Widget _lbl(String t, CestovniColors c) =>
      Text(t, style: CestovniTypography.labelMono(color: c.mutedForeground));

  Widget _err(String t, CestovniColors c) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(t, style: TextStyle(color: c.destructive, fontSize: 12)));

  Widget _txt(String label, TextEditingController ctrl, String errKey,
      CestovniColors c,
      {TextInputType kb = TextInputType.text}) {
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

  Widget _dateField(BuildContext context, CestovniColors c) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _filledAt,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(hours: 24)),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_filledAt),
        );
        if (time == null || !context.mounted) return;
        setState(() {
          _filledAt = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        });
      },
      child: InputDecorator(
        decoration: _deco(c),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _DetailSheet._fmtFull(_filledAt),
                style: CestovniTypography.mono(fontSize: 14, color: c.ink),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 18, color: c.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String title, String sub, bool value,
      ValueChanged<bool> onChanged, CestovniColors c) {
    return LedgerTile(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: CestovniTypography.labelMono(color: c.ink)),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        TextStyle(color: c.mutedForeground, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: c.accent),
        ],
      ),
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
}
