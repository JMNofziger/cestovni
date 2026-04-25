import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// Create / edit form for a single vehicle.
///
/// CES-39 phase 2: backs the **Add vehicle** and **Edit vehicle**
/// flows surfaced in [SettingsPage] and from the shell empty-state
/// `NO VEHICLE` chip. Reads / writes through [VehiclesRepository] so
/// the persistence rules (mutation_id, soft-delete invariants) live in
/// one place.
///
/// The constructor takes a nullable [VehicleRow] — `null` means
/// **create**, non-null means **edit**. On save, [onSaved] gets the
/// row id so callers can immediately set it as active.
class VehicleFormPage extends StatefulWidget {
  const VehicleFormPage({
    super.key,
    required this.db,
    this.existing,
    this.onSaved,
  });

  final AppDatabase db;
  final VehicleRow? existing;
  final ValueChanged<String>? onSaved;

  bool get isEdit => existing != null;

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final VehiclesRepository _repo;

  late final TextEditingController _name;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _vin;
  late final TextEditingController _tankCapacityLitres;
  late VehicleFuelType _fuelType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = VehiclesRepository(widget.db);
    final v = widget.existing;
    _name = TextEditingController(text: v?.name ?? '');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _tankCapacityLitres = TextEditingController(
      text: v?.tankCapacityUL == null ? '' : _formatLitres(v!.tankCapacityUL!),
    );
    _fuelType = v == null
        ? VehicleFuelType.gasoline
        : VehicleFuelType.fromWire(v.fuelType);
  }

  @override
  void dispose() {
    _name.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _vin.dispose();
    _tankCapacityLitres.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit vehicle' : 'Add vehicle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              widget.isEdit ? 'SAVE' : 'ADD',
              style: CestovniTypography.labelMono(color: colors.ink),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
          children: [
            _Field(
              controller: _name,
              label: 'Name *',
              hint: 'My Octavia',
              autofocus: !widget.isEdit,
              maxLength: 80,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Name is required.';
                if (s.length > 80) return 'Max 80 characters.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _FuelTypeField(
              value: _fuelType,
              onChanged: (t) => setState(() => _fuelType = t),
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _make,
              label: 'Make',
              hint: 'Škoda',
              maxLength: 80,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _model,
              label: 'Model',
              hint: 'Octavia',
              maxLength: 80,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _year,
              label: 'Year',
              hint: '2020',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final n = int.tryParse(s);
                if (n == null) return 'Numbers only.';
                if (n < 1900 || n > 2100) return 'Year must be 1900-2100.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _vin,
              label: 'VIN',
              hint: '17 characters',
              maxLength: 32,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _tankCapacityLitres,
              label: 'Tank capacity (L)',
              hint: '50',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final parsed = _parseLitresToUL(s);
                if (parsed == null) return 'Enter a number (e.g. 50 or 47.5).';
                if (parsed < 0) return 'Tank capacity cannot be negative.';
                return null;
              },
            ),
            const SizedBox(height: CestovniMetrics.sectionGap),
            Text(
              '* required',
              style: CestovniTypography.labelMono(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final draft = VehicleDraft(
      name: _name.text.trim(),
      fuelType: _fuelType,
      make: _emptyToNull(_make.text),
      model: _emptyToNull(_model.text),
      year: _emptyToNull(_year.text) == null ? null : int.parse(_year.text),
      vin: _emptyToNull(_vin.text)?.toUpperCase(),
      tankCapacityUL: _parseLitresToUL(_tankCapacityLitres.text),
    );

    try {
      String id;
      if (widget.isEdit) {
        await _repo.update(widget.existing!.id, draft);
        id = widget.existing!.id;
      } else {
        id = await _repo.create(draft);
      }
      if (!mounted) return;
      widget.onSaved?.call(id);
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save vehicle: $e')),
      );
    }
  }

  static String? _emptyToNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// Parse a litres string (e.g. `"50"`, `"47.5"`) into microlitres
  /// (`int`). Returns null on empty input or unparseable strings.
  /// Float math is bounded to the parse step; storage stays INT64.
  static int? _parseLitresToUL(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final dotIdx = s.indexOf('.');
    if (dotIdx == -1) {
      final n = int.tryParse(s);
      return n == null ? null : n * 1000000;
    }
    final whole = s.substring(0, dotIdx);
    final frac = s.substring(dotIdx + 1);
    if (frac.isEmpty || frac.length > 6) return null;
    final wholeN = int.tryParse(whole.isEmpty ? '0' : whole);
    final fracN = int.tryParse(frac);
    if (wholeN == null || fracN == null) return null;
    final fracPadded = fracN * _powerOfTen(6 - frac.length);
    return wholeN * 1000000 + fracPadded;
  }

  static String _formatLitres(int microlitres) {
    final whole = microlitres ~/ 1000000;
    final frac = microlitres % 1000000;
    if (frac == 0) return whole.toString();
    var s = frac.toString().padLeft(6, '0');
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return '$whole.$s';
  }

  static int _powerOfTen(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}

class _FuelTypeField extends StatelessWidget {
  const _FuelTypeField({required this.value, required this.onChanged});

  final VehicleFuelType value;
  final ValueChanged<VehicleFuelType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<VehicleFuelType>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Fuel type *',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: VehicleFuelType.gasoline,
          child: Text('Gasoline'),
        ),
        DropdownMenuItem(
          value: VehicleFuelType.diesel,
          child: Text('Diesel'),
        ),
        DropdownMenuItem(
          value: VehicleFuelType.lpg,
          child: Text('LPG'),
        ),
        DropdownMenuItem(
          value: VehicleFuelType.cng,
          child: Text('CNG'),
        ),
        DropdownMenuItem(
          value: VehicleFuelType.evKwh,
          child: Text('Electric (kWh)'),
        ),
        DropdownMenuItem(
          value: VehicleFuelType.other,
          child: Text('Other'),
        ),
      ],
      onChanged: (t) {
        if (t != null) onChanged(t);
      },
    );
  }
}
