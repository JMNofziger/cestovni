import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../consumption/adapters.dart';
import '../../consumption/models.dart';
import '../../consumption/validation.dart';
import '../../db/app_database.dart';
import '../../db/repositories/drafts_repository.dart';
import '../../db/repositories/fill_ups_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../../units/display_units.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Log** tab — fast-entry fill-up form per `cestovni-views.md`.
///
/// CES-39: replaces M1 stub with working form + draft lifecycle.
class LogPage extends StatefulWidget {
  const LogPage({
    super.key,
    required this.db,
    required this.onOpenSettings,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late final FillUpsRepository _fillUps;
  late final DraftsRepository _drafts;
  late final SettingsRepository _settingsRepo;

  /// Latest settings row (CES-65) — entry labels and save-time unit /
  /// currency conversion follow these prefs. Defaults (km / L / EUR)
  /// apply until the bootstrap read lands.
  SettingsRow? _settings;
  StreamSubscription<SettingsRow?>? _settingsSub;

  final _odometerCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _filledAt = DateTime.now();
  bool _partialFill = false;
  bool _missedBefore = false;
  bool _odometerReset = false;

  String? _draftId;
  String? _trackedVehicleId;
  int _draftLoadToken = 0;
  Timer? _autoSaveTimer;
  bool _saving = false;
  bool _showAdvanced = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _fillUps = FillUpsRepository(widget.db);
    _drafts = DraftsRepository(widget.db);
    _settingsRepo = SettingsRepository(widget.db);
    _settingsSub = _settingsRepo.watchSingle().listen((row) {
      if (mounted && row != null) setState(() => _settings = row);
    });
    for (final c in [_odometerCtrl, _volumeCtrl, _totalCtrl, _notesCtrl]) {
      c.addListener(_scheduleAutoSave);
    }
  }

  String get _distanceUnit => _settings?.preferredDistanceUnit ?? 'km';
  String get _volumeUnit => _settings?.preferredVolumeUnit ?? 'L';
  String get _currencyCode => _settings?.currencyCode ?? 'EUR';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vehicleId = ActiveVehicleScope.of(context).vehicleId;
    if (vehicleId != _trackedVehicleId) {
      if (_trackedVehicleId != null) _saveDraftNow();
      _trackedVehicleId = vehicleId;
      _draftLoadToken += 1;
      _loadDraft(vehicleId, _draftLoadToken);
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _autoSaveTimer?.cancel();
    _odometerCtrl.dispose();
    _volumeCtrl.dispose();
    _totalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────── Draft lifecycle

  Future<void> _loadDraft(String? vehicleId, int loadToken) async {
    if (vehicleId == null) {
      _resetForm();
      return;
    }
    // Prefs must be known before canonical draft values are rendered
    // back into entry units (CES-65).
    _settings ??= await _settingsRepo.getOrBootstrap();
    final draft = await _drafts.openDraftForVehicle(vehicleId);
    if (!mounted || loadToken != _draftLoadToken) return;
    if (draft == null) {
      _resetForm();
      return;
    }
    setState(() {
      _draftId = draft.id;
      if (draft.filledAt != null) {
        _filledAt = DateTime.parse(draft.filledAt!).toLocal();
      }
      if (draft.odometerM != null) {
        _odometerCtrl.text =
            metersToDisplayWhole(draft.odometerM!, _distanceUnit).toString();
      }
      if (draft.volumeUL != null) {
        final vol = microlitersToDouble(draft.volumeUL!, _volumeUnit);
        _volumeCtrl.text = vol == vol.roundToDouble()
            ? vol.toStringAsFixed(0)
            : vol.toStringAsFixed(3);
      }
      if (draft.totalPriceCents != null) {
        _totalCtrl.text = (draft.totalPriceCents! / 100).toStringAsFixed(2);
      }
      if (draft.notes != null) _notesCtrl.text = draft.notes!;
      _partialFill = draft.isFull == 0;
      _missedBefore = draft.missedBefore == 1;
      _odometerReset = draft.odometerReset == 1;
    });
  }

  void _resetForm() {
    _draftId = null;
    _filledAt = DateTime.now();
    _odometerCtrl.clear();
    _volumeCtrl.clear();
    _totalCtrl.clear();
    _notesCtrl.clear();
    _partialFill = false;
    _missedBefore = false;
    _odometerReset = false;
    _errors = {};
    if (mounted) setState(() {});
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    final vehicleId = _trackedVehicleId;
    if (vehicleId == null) return;

    final odometerVal = int.tryParse(_odometerCtrl.text.trim());
    final volumeVal = double.tryParse(_volumeCtrl.text.trim());
    final totalMajor = double.tryParse(_totalCtrl.text.trim());
    final notes = _notesCtrl.text.trim();

    final savedDraftId = await _drafts.save(DraftSnapshot(
      vehicleId: vehicleId,
      filledAt: _filledAt.toUtc(),
      odometerM: odometerVal != null
          ? distanceToMeters(odometerVal.toDouble(), _distanceUnit)
          : null,
      volumeUL: volumeVal != null
          ? volumeToMicroliters(volumeVal, _volumeUnit)
          : null,
      totalPriceCents: totalMajor != null ? majorToCents(totalMajor) : null,
      currencyCode: _currencyCode,
      isFull: !_partialFill,
      missedBefore: _missedBefore,
      odometerReset: _odometerReset,
      notes: notes.isEmpty ? null : notes,
    ));
    if (_trackedVehicleId == vehicleId) {
      _draftId = savedDraftId;
    }
  }

  // ────────────────────────────── Save entry

  Future<void> _saveEntry() async {
    final vehicleId = _trackedVehicleId;
    if (vehicleId == null) return;

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

    final odometerM =
        distanceToMeters(odometerVal!.toDouble(), _distanceUnit);
    final volumeUL = volumeToMicroliters(volumeVal!, _volumeUnit);
    final totalCents = majorToCents(totalMajor!);
    final notes = _notesCtrl.text.trim();

    final candidate = FillUp(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      filledAt: _filledAt.toUtc(),
      odometerM: odometerM,
      volumeUL: volumeUL,
      totalPriceCents: totalCents,
      currencyCode: _currencyCode,
      isFull: !_partialFill,
      missedBefore: _missedBefore,
      odometerReset: _odometerReset,
      notes: notes.isEmpty ? null : notes,
    );

    final existingRows = await _fillUps.listForVehicle(vehicleId);
    final existing = fillUpsFromRows(existingRows);

    final failure = validateInsert(candidate, existing, DateTime.now().toUtc());
    if (failure != null) {
      setState(() {
        _errors = _mapValidationError(failure);
        _saving = false;
      });
      return;
    }

    await _fillUps.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: _filledAt.toUtc(),
      odometerM: odometerM,
      volumeUL: volumeUL,
      totalPriceCents: totalCents,
      currencyCode: _currencyCode,
      isFull: !_partialFill,
      missedBefore: _missedBefore,
      odometerReset: _odometerReset,
      notes: notes.isEmpty ? null : notes,
    ));

    if (_draftId != null) await _drafts.markCompleted(_draftId!);

    if (!mounted) return;
    _resetForm();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fill-up saved')),
    );
  }

  Map<String, String> _mapValidationError(ValidationFailure f) {
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

  // ────────────────────────────── Build

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final vehicleId = ActiveVehicleScope.of(context).vehicleId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: CestovniMetrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Log a Fuel-Up',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Text(
                    'ENTRY',
                    style: CestovniTypography.labelMono(
                        color: colors.mutedForeground),
                  ),
                ],
              ),
              const SizedBox(height: CestovniMetrics.sectionGap),
              if (vehicleId == null)
                _NoVehicleCard(onTap: widget.onOpenSettings)
              else ...[
                _buildFormCard(context, colors),
                const SizedBox(height: 12),
                _buildAdvancedSection(colors),
                const SizedBox(height: CestovniMetrics.sectionGap),
                _buildSaveButton(colors),
                const SizedBox(height: CestovniMetrics.sectionGap),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Form card

  Widget _buildFormCard(BuildContext context, CestovniColors colors) {
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('DATE & TIME', colors),
          const SizedBox(height: 6),
          _buildDateTimeField(context, colors),
          if (_errors.containsKey('date')) _errorText(_errors['date']!, colors),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                    'ODOMETER (${distanceUnitLabel(_distanceUnit)})',
                    _odometerCtrl,
                    'odometer',
                    colors,
                    keyboard: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                    'VOLUME (${volumeUnitLabel(_volumeUnit)})',
                    _volumeCtrl,
                    'volume',
                    colors,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _field('TOTAL (${currencySymbol(_currencyCode).trim()})',
              _totalCtrl, 'total', colors,
              keyboard:
                  const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          _buildToggleRow(
            'PARTIAL FILL',
            'Tank not filled to full',
            _partialFill,
            (v) => setState(() {
              _partialFill = v;
              _scheduleAutoSave();
            }),
            colors,
          ),
          const SizedBox(height: 16),
          _label('NOTES (OPT.)', colors),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            style: TextStyle(color: colors.ink),
            decoration: _inputDeco(colors),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── Advanced

  Widget _buildAdvancedSection(CestovniColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              Text('ADVANCED',
                  style: CestovniTypography.labelMono(
                      color: colors.mutedForeground)),
              const SizedBox(width: 4),
              Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: colors.mutedForeground,
              ),
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 8),
          _buildToggleRow(
            'MISSED BEFORE',
            'I missed one or more fill-ups before this one',
            _missedBefore,
            (v) => setState(() {
              _missedBefore = v;
              _scheduleAutoSave();
            }),
            colors,
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            'ODOMETER RESET',
            'Odometer was reset (new engine or dash replacement)',
            _odometerReset,
            (v) => setState(() {
              _odometerReset = v;
              _scheduleAutoSave();
            }),
            colors,
          ),
          if (_errors.containsKey('reset'))
            _errorText(_errors['reset']!, colors),
        ],
      ],
    );
  }

  // ────────────────────────────── Shared field builders

  Widget _label(String text, CestovniColors colors) {
    return Text(text,
        style: CestovniTypography.labelMono(color: colors.mutedForeground));
  }

  Widget _errorText(String text, CestovniColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text,
          style: TextStyle(color: colors.destructive, fontSize: 12)),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String errorKey,
    CestovniColors colors, {
    TextInputType keyboard = TextInputType.text,
  }) {
    final error = _errors[errorKey];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, colors),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          style: TextStyle(color: colors.ink, fontSize: 16),
          decoration: _inputDeco(colors, error: error),
        ),
        if (error != null) _errorText(error, colors),
      ],
    );
  }

  Widget _buildDateTimeField(BuildContext context, CestovniColors colors) {
    return GestureDetector(
      onTap: () => _pickDateTime(context),
      child: InputDecorator(
        decoration: _inputDeco(colors),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fmtDateTime(_filledAt),
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

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    CestovniColors colors,
  ) {
    return LedgerTile(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: CestovniTypography.labelMono(color: colors.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: colors.mutedForeground, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(CestovniColors colors) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.paper,
          disabledBackgroundColor: colors.rule,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
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
    );
  }

  // ────────────────────────────── Helpers

  InputDecoration _inputDeco(CestovniColors colors, {String? error}) {
    final borderColor = error != null ? colors.destructive : colors.ink;
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: colors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: borderColor, width: CestovniMetrics.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: borderColor, width: CestovniMetrics.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        borderSide: BorderSide(color: colors.ink, width: 2),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
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
      _scheduleAutoSave();
    });
  }

  static String _fmtDateTime(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m/$d/${dt.year},  ${h.toString().padLeft(2, '0')}:$min $ampm';
  }
}

// ══════════════════════════════════════════════════════════════════════
// No-vehicle empty state (matches add-vehicle-cta.png screenshot).
// ══════════════════════════════════════════════════════════════════════

class _NoVehicleCard extends StatelessWidget {
  const _NoVehicleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return LedgerCard(
      child: Column(
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
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.paper,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }
}
