/// Manifest gates, header strictness and per-column validation (CES-70).
///
/// Spec: `docs/specs/export-import.md` § Input contract, § Invariants,
/// § Value validation, § Error handling.
///
/// Nothing here writes. A plan is only produced when every gate passes,
/// which is what makes "either a valid new state or the database is
/// byte-identical" achievable — by the time `apply.dart` runs, the only
/// remaining failure modes are disk and constraint errors.
///
/// Pure module: no Flutter, no Drift, no `dart:io`.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../export/headers.dart';
import '../export/manifest.dart' show exportSchemaVersion;
import '../photos/photo_export_guard.dart';
import 'csv_parse.dart';
import 'import_errors.dart';
import 'plan.dart';

/// Manifest `schema_version` this build understands.
///
/// Taken from the export module rather than restated, so bumping the
/// export format cannot leave import silently accepting the old one.
const int supportedImportSchemaVersion = exportSchemaVersion;

const String manifestEntryName = 'manifest.json';
const String readmeEntryName = 'README_export.txt';

const Set<String> _fuelTypes = {
  'gasoline',
  'diesel',
  'lpg',
  'cng',
  'ev_kwh',
  'other',
};

const Set<String> _maintenanceCategories = {
  'oil',
  'tires',
  'brakes',
  'inspection',
  'battery',
  'fluid',
  'other',
};

const Set<String> _distanceUnits = {'km', 'mi'};
const Set<String> _volumeUnits = {'L', 'gal'};

const Set<String> _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
  '.gif',
};

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final RegExp _currencyPattern = RegExp(r'^[A-Z]{3}$');

/// CSV entry name → its authoritative header, taken from the **export**
/// constants so the two contracts cannot drift.
const Map<String, String> importCsvHeaders = <String, String>{
  'vehicles.csv': vehiclesCsvHeader,
  'fill_ups.csv': fillUpsCsvHeader,
  'maintenance_rules.csv': maintenanceRulesCsvHeader,
  'maintenance_events.csv': maintenanceEventsCsvHeader,
  'settings.csv': settingsCsvHeader,
};

/// Build a validated [ImportPlan] from raw ZIP entries.
///
/// [localUserKeyHash] is only used to raise
/// [ImportWarningCode.differentSourceKey]; a mismatch never rejects,
/// because device-to-device transfer is the normal case.
ImportPlan buildImportPlan(
  Map<String, Uint8List> entries, {
  required String localUserKeyHash,
}) {
  final warnings = <ImportWarning>[];

  _guardPhotoContent(entries);
  _guardEntrySet(entries, warnings);

  final manifest = _readManifest(entries[manifestEntryName]!);

  // A differing key is the normal device-to-device case, so it warns and
  // never rejects (spec § Product decisions → Cross-account imports). An
  // empty local hash means this device has no identity yet, so there is
  // nothing to compare.
  if (localUserKeyHash.isNotEmpty &&
      manifest.userKeyHash != localUserKeyHash) {
    warnings.add(ImportWarning(
      ImportWarningCode.differentSourceKey,
      'This archive came from key ${manifest.userKeyHash}; this device is '
      '$localUserKeyHash.',
    ));
  }
  if (manifest.outboxPendingCount > 0) {
    warnings.add(ImportWarning(
      ImportWarningCode.sourceHadPendingOutbox,
      '${manifest.outboxPendingCount} change(s) on the source device had '
      'not been saved to a server when this archive was made.',
    ));
  }

  final vehicles = _readVehicles(_records(entries, 'vehicles.csv'));
  final rules = _readRules(_records(entries, 'maintenance_rules.csv'));
  final fillUps = _readFillUps(_records(entries, 'fill_ups.csv'));
  final events = _readEvents(_records(entries, 'maintenance_events.csv'));
  final settings = _readSettings(_records(entries, 'settings.csv'));

  _assertCounts(manifest, {
    'vehicles': vehicles.length,
    'fill_ups': fillUps.length,
    'maintenance_rules': rules.length,
    'maintenance_events': events.length,
    'settings': 1,
  });

  _assertReferences(
    vehicles: vehicles,
    rules: rules,
    fillUps: fillUps,
    events: events,
  );

  return ImportPlan(
    manifest: manifest,
    vehicles: vehicles,
    fillUps: fillUps,
    maintenanceRules: rules,
    maintenanceEvents: events,
    settings: settings,
    warnings: warnings,
  );
}

// ───────────────────────────────────────────── entry-level gates

/// Fail closed on anything photo-shaped. Photos are never exported and
/// must never be imported; the guard from CES-40 decides what counts as
/// photo content so import does not re-litigate it.
void _guardPhotoContent(Map<String, Uint8List> entries) {
  for (final entry in entries.entries) {
    final name = entry.key;
    if (isPhotoSandboxPath(name)) {
      throw ImportException(
        ImportErrorCode.photosPresent,
        'Archive contains photo content, which is never part of an '
        'export.',
        file: name,
      );
    }
    if (name == 'photo_refs.csv') {
      throw ImportException(
        ImportErrorCode.photosPresent,
        'Archive contains a photo index, which is never part of an '
        'export.',
        file: name,
      );
    }
    final lower = name.toLowerCase();
    if (_imageExtensions.any(lower.endsWith)) {
      throw ImportException(
        ImportErrorCode.photosPresent,
        'Archive contains an image file.',
        file: name,
      );
    }
    if (_looksLikeImageBytes(entry.value)) {
      throw ImportException(
        ImportErrorCode.photosPresent,
        'Archive contains image data.',
        file: name,
      );
    }
  }
}

bool _looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true;
  }
  return bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

void _guardEntrySet(
  Map<String, Uint8List> entries,
  List<ImportWarning> warnings,
) {
  if (!entries.containsKey(manifestEntryName)) {
    throw const ImportException(
      ImportErrorCode.missingManifest,
      'This file is missing manifest.json, so it is not a Cestovni '
      'export.',
      file: manifestEntryName,
    );
  }
  for (final csv in importCsvHeaders.keys) {
    if (!entries.containsKey(csv)) {
      throw ImportException(
        ImportErrorCode.missingCsv,
        'Archive is missing $csv.',
        file: csv,
      );
    }
  }

  // Extra entries are ignored rather than rejected: cloud tools add
  // `__MACOSX/`, and users add notes next to their backup. Anything
  // photo-shaped already failed closed above.
  final known = <String>{
    manifestEntryName,
    readmeEntryName,
    ...importCsvHeaders.keys,
  };
  for (final name in entries.keys) {
    if (known.contains(name)) continue;
    warnings.add(ImportWarning(
      ImportWarningCode.unknownEntry,
      'Ignored unexpected file in the archive: $name',
    ));
  }
}

// ───────────────────────────────────────────── manifest

ImportedManifest _readManifest(Uint8List bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    throw const ImportException(
      ImportErrorCode.manifestInvalid,
      'manifest.json is not readable JSON.',
      file: manifestEntryName,
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const ImportException(
      ImportErrorCode.manifestInvalid,
      'manifest.json is not a JSON object.',
      file: manifestEntryName,
    );
  }

  final schemaVersion = decoded['schema_version'];
  if (schemaVersion is! int) {
    throw const ImportException(
      ImportErrorCode.manifestInvalid,
      'manifest.json has no schema_version.',
      file: manifestEntryName,
    );
  }
  if (schemaVersion != supportedImportSchemaVersion) {
    throw ImportException(
      ImportErrorCode.schemaVersionUnsupported,
      'This archive uses export format $schemaVersion; this version of '
      'Cestovni reads format $supportedImportSchemaVersion. Update the '
      'app and try again.',
      file: manifestEntryName,
    );
  }

  final photos = decoded['photos_in_export'];
  if (photos != false) {
    throw const ImportException(
      ImportErrorCode.photosPresent,
      'manifest.json does not declare photos_in_export: false.',
      file: manifestEntryName,
    );
  }

  if (decoded['max_row_version_seen'] != null) {
    throw const ImportException(
      ImportErrorCode.rowVersionPresent,
      'This archive carries server row versions, which this version of '
      'Cestovni cannot import.',
      file: manifestEntryName,
    );
  }

  final rawCounts = decoded['row_counts'];
  if (rawCounts is! Map<String, Object?>) {
    throw const ImportException(
      ImportErrorCode.manifestInvalid,
      'manifest.json has no row_counts.',
      file: manifestEntryName,
    );
  }
  final counts = <String, int>{};
  for (final entry in rawCounts.entries) {
    final value = entry.value;
    if (value is! int) {
      throw ImportException(
        ImportErrorCode.manifestInvalid,
        'row_counts.${entry.key} is not a whole number.',
        file: manifestEntryName,
      );
    }
    counts[entry.key] = value;
  }

  final pending = decoded['outbox_pending_count'];

  return ImportedManifest(
    schemaVersion: schemaVersion,
    exportedAtUtc: _manifestString(decoded, 'exported_at_utc'),
    appVersion: _manifestString(decoded, 'app_version'),
    appPlatform: _manifestString(decoded, 'app_platform'),
    timezone: _manifestString(decoded, 'timezone'),
    userKeyHash: _manifestString(decoded, 'user_key_hash'),
    outboxPendingCount: pending is int ? pending : 0,
    rowCounts: counts,
  );
}

String _manifestString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw ImportException(
      ImportErrorCode.manifestInvalid,
      'manifest.json has no $key.',
      file: manifestEntryName,
    );
  }
  return value;
}

void _assertCounts(ImportedManifest manifest, Map<String, int> actual) {
  for (final entry in actual.entries) {
    final declared = manifest.rowCounts[entry.key];
    if (declared == null) {
      throw ImportException(
        ImportErrorCode.manifestInvalid,
        'row_counts is missing ${entry.key}.',
        file: manifestEntryName,
      );
    }
    if (declared != entry.value) {
      throw ImportException(
        ImportErrorCode.countMismatch,
        'Archive declares $declared ${entry.key} row(s) but contains '
        '${entry.value}. The file appears to have been edited.',
        file: '${entry.key}.csv',
      );
    }
  }
}

// ───────────────────────────────────────────── header + record access

/// Header-checked records for [file], excluding the header row itself.
_Table _records(Map<String, Uint8List> entries, String file) {
  final expected = importCsvHeaders[file]!;
  final String text;
  try {
    text = utf8.decode(entries[file]!);
  } on FormatException {
    throw ImportException(
      ImportErrorCode.rowMalformed,
      '$file is not valid UTF-8.',
      file: file,
    );
  }

  final records = parseCsv(text, file: file);
  if (records.isEmpty) {
    throw ImportException(
      ImportErrorCode.headerMismatch,
      '$file is empty.',
      file: file,
    );
  }

  final actualHeader = records.first.fields.join(',');
  if (actualHeader != expected) {
    throw ImportException(
      ImportErrorCode.headerMismatch,
      'Unexpected columns in $file.\nExpected: $expected\nFound:    '
      '$actualHeader',
      file: file,
      line: records.first.line,
    );
  }

  return _Table(
    file: file,
    columns: expected.split(','),
    rows: records.skip(1).toList(),
  );
}

/// A header-validated CSV: fixed column order plus its data records.
class _Table {
  _Table({required this.file, required this.columns, required this.rows})
      : _index = {
          for (var i = 0; i < columns.length; i++) columns[i]: i,
        };

  final String file;
  final List<String> columns;
  final List<CsvRecord> rows;
  final Map<String, int> _index;

  _Row row(CsvRecord record) {
    if (record.fields.length != columns.length) {
      throw ImportException(
        ImportErrorCode.rowMalformed,
        'Expected ${columns.length} values but found '
        '${record.fields.length}.',
        file: file,
        line: record.line,
      );
    }
    return _Row(table: this, record: record);
  }
}

/// One data record, addressed by column name.
class _Row {
  const _Row({required this.table, required this.record});

  final _Table table;
  final CsvRecord record;

  String get file => table.file;
  int get line => record.line;

  String raw(String column) => record.fields[table._index[column]!];

  /// `row_version` must always be empty: the client never assigns one
  /// before M3, so a populated cell means the archive is not something
  /// this build produced.
  void assertRowVersionEmpty() {
    if (raw('row_version').isNotEmpty) {
      throw ImportException(
        ImportErrorCode.rowVersionPresent,
        'This archive carries server row versions, which this version of '
        'Cestovni cannot import.',
        file: file,
        line: line,
        column: 'row_version',
      );
    }
  }

  String uuid(String column) {
    final value = readRequiredText(
      raw(column),
      file: file,
      line: line,
      column: column,
    );
    if (!_uuidPattern.hasMatch(value)) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected a UUID, got "$value".',
        file: file,
        line: line,
        column: column,
      );
    }
    return value;
  }

  String? nullableUuid(String column) {
    if (raw(column).isEmpty) return null;
    return uuid(column);
  }

  String text(String column, {required int min, required int max}) {
    final value = readRequiredText(
      raw(column),
      file: file,
      line: line,
      column: column,
    );
    _assertLength(value, column: column, min: min, max: max);
    return value;
  }

  String? nullableText(String column, {int min = 0, required int max}) {
    final value = readNullableText(raw(column));
    if (value == null) return null;
    _assertLength(value, column: column, min: min, max: max);
    return value;
  }

  void _assertLength(
    String value, {
    required String column,
    required int min,
    required int max,
  }) {
    if (value.length < min || value.length > max) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected between $min and $max characters, got ${value.length}.',
        file: file,
        line: line,
        column: column,
      );
    }
  }

  String oneOf(String column, Set<String> allowed) {
    final value = readRequiredText(
      raw(column),
      file: file,
      line: line,
      column: column,
    );
    if (!allowed.contains(value)) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected one of ${allowed.join(', ')}, got "$value".',
        file: file,
        line: line,
        column: column,
      );
    }
    return value;
  }

  String currency(String column) {
    final value = readRequiredText(
      raw(column),
      file: file,
      line: line,
      column: column,
    );
    if (!_currencyPattern.hasMatch(value)) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected a three-letter uppercase currency code, got "$value".',
        file: file,
        line: line,
        column: column,
      );
    }
    return value;
  }

  int nonNegativeInt(String column) {
    final value =
        readRequiredInt(raw(column), file: file, line: line, column: column);
    return _assertAtLeast(value, 0, column);
  }

  int? nullableNonNegativeInt(String column) {
    final value =
        readNullableInt(raw(column), file: file, line: line, column: column);
    if (value == null) return null;
    return _assertAtLeast(value, 0, column);
  }

  int? nullablePositiveInt(String column) {
    final value =
        readNullableInt(raw(column), file: file, line: line, column: column);
    if (value == null) return null;
    return _assertAtLeast(value, 1, column);
  }

  int? nullableIntInRange(String column, {required int min, required int max}) {
    final value =
        readNullableInt(raw(column), file: file, line: line, column: column);
    if (value == null) return null;
    if (value < min || value > max) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected a value between $min and $max, got $value.',
        file: file,
        line: line,
        column: column,
      );
    }
    return value;
  }

  int _assertAtLeast(int value, int min, String column) {
    if (value < min) {
      throw ImportException(
        ImportErrorCode.valueInvalid,
        'Expected a value of at least $min, got $value.',
        file: file,
        line: line,
        column: column,
      );
    }
    return value;
  }

  bool boolean(String column) =>
      readRequiredBool(raw(column), file: file, line: line, column: column);

  String timestamp(String column) =>
      readTimestampUtc(raw(column), file: file, line: line, column: column);

  String? nullableTimestamp(String column) => readNullableTimestampUtc(
        raw(column),
        file: file,
        line: line,
        column: column,
      );
}

/// Reject a repeated `id` inside one CSV — it would make the import
/// non-deterministic and, under replace, silently drop a row.
void _assertUniqueId(Set<String> seen, String id, _Row row) {
  if (!seen.add(id)) {
    throw ImportException(
      ImportErrorCode.duplicateId,
      'Duplicate id "$id" in ${row.file}.',
      file: row.file,
      line: row.line,
      column: 'id',
    );
  }
}

// ───────────────────────────────────────────── per-table readers

List<ImportedVehicle> _readVehicles(_Table table) {
  final seen = <String>{};
  final out = <ImportedVehicle>[];
  for (final record in table.rows) {
    final row = table.row(record);
    row.assertRowVersionEmpty();
    final id = row.uuid('id');
    _assertUniqueId(seen, id, row);
    out.add(ImportedVehicle(
      id: id,
      name: row.text('name', min: 1, max: 80),
      make: row.nullableText('make', max: 80),
      model: row.nullableText('model', max: 80),
      year: row.nullableIntInRange('year', min: 1900, max: 2100),
      vin: row.nullableText('vin', max: 32),
      fuelType: row.oneOf('fuel_type', _fuelTypes),
      tankCapacityUL: row.nullableNonNegativeInt('tank_capacity_uL'),
      archivedAt: row.nullableTimestamp('archived_at_utc'),
      updatedAt: row.timestamp('updated_at_utc'),
    ));
  }
  return out;
}

List<ImportedFillUp> _readFillUps(_Table table) {
  final seen = <String>{};
  final out = <ImportedFillUp>[];
  for (final record in table.rows) {
    final row = table.row(record);
    row.assertRowVersionEmpty();
    final id = row.uuid('id');
    _assertUniqueId(seen, id, row);
    out.add(ImportedFillUp(
      id: id,
      vehicleId: row.uuid('vehicle_id'),
      filledAt: row.timestamp('filled_at_utc'),
      odometerM: row.nonNegativeInt('odometer_m'),
      volumeUL: row.nonNegativeInt('volume_uL'),
      totalPriceCents: row.nonNegativeInt('total_price_cents'),
      currencyCode: row.currency('currency_code'),
      isFull: row.boolean('is_full'),
      missedBefore: row.boolean('missed_before'),
      odometerReset: row.boolean('odometer_reset'),
      notes: row.nullableText('notes', max: 500),
      updatedAt: row.timestamp('updated_at_utc'),
    ));
  }
  return out;
}

List<ImportedMaintenanceRule> _readRules(_Table table) {
  final seen = <String>{};
  final out = <ImportedMaintenanceRule>[];
  for (final record in table.rows) {
    final row = table.row(record);
    row.assertRowVersionEmpty();
    final id = row.uuid('id');
    _assertUniqueId(seen, id, row);

    // `cadence_km` holds canonical meters (export-v1.md § A3). Read
    // verbatim — no conversion in either direction.
    final cadenceMeters = row.nullablePositiveInt('cadence_km');
    final cadenceDays = row.nullablePositiveInt('cadence_days');
    if (cadenceMeters == null && cadenceDays == null) {
      throw ImportException(
        ImportErrorCode.cadenceMissing,
        'A maintenance rule needs a distance or a time interval.',
        file: row.file,
        line: row.line,
      );
    }

    out.add(ImportedMaintenanceRule(
      id: id,
      vehicleId: row.uuid('vehicle_id'),
      name: row.text('name', min: 1, max: 80),
      cadenceMeters: cadenceMeters,
      cadenceDays: cadenceDays,
      enabled: row.boolean('enabled'),
      notes: row.nullableText('notes', max: 500),
      updatedAt: row.timestamp('updated_at_utc'),
    ));
  }
  return out;
}

List<ImportedMaintenanceEvent> _readEvents(_Table table) {
  final seen = <String>{};
  final out = <ImportedMaintenanceEvent>[];
  for (final record in table.rows) {
    final row = table.row(record);
    row.assertRowVersionEmpty();
    final id = row.uuid('id');
    _assertUniqueId(seen, id, row);
    out.add(ImportedMaintenanceEvent(
      id: id,
      vehicleId: row.uuid('vehicle_id'),
      ruleId: row.nullableUuid('rule_id'),
      performedAt: row.timestamp('performed_at_utc'),
      odometerM: row.nullableNonNegativeInt('odometer_m'),
      costCents: row.nonNegativeInt('cost_cents'),
      currencyCode: row.currency('currency_code'),
      category: row.oneOf('category', _maintenanceCategories),
      shop: row.nullableText('shop', min: 1, max: 120),
      notes: row.nullableText('notes', max: 500),
      updatedAt: row.timestamp('updated_at_utc'),
    ));
  }
  return out;
}

ImportedSettings _readSettings(_Table table) {
  if (table.rows.length != 1) {
    throw ImportException(
      ImportErrorCode.settingsRowCount,
      'Expected exactly one settings row, found ${table.rows.length}.',
      file: table.file,
    );
  }
  final row = table.row(table.rows.single);
  row.assertRowVersionEmpty();
  return ImportedSettings(
    preferredDistanceUnit: row.oneOf('preferred_distance_unit', _distanceUnits),
    preferredVolumeUnit: row.oneOf('preferred_volume_unit', _volumeUnits),
    currencyCode: row.currency('currency_code'),
    timezone: row.text('timezone', min: 1, max: 64),
    defaultVehicleId: row.nullableUuid('default_vehicle_id'),
    updatedAt: row.timestamp('updated_at_utc'),
  );
}

// ───────────────────────────────────────────── referential integrity

/// Under replace the four history tables are cleared first, so every
/// reference must resolve **within the archive** — there is no
/// "already live locally" fallback. An orphan would be invisible in
/// History (which filters by vehicle), i.e. silent data loss reported as
/// success.
void _assertReferences({
  required List<ImportedVehicle> vehicles,
  required List<ImportedMaintenanceRule> rules,
  required List<ImportedFillUp> fillUps,
  required List<ImportedMaintenanceEvent> events,
}) {
  final vehicleIds = vehicles.map((v) => v.id).toSet();
  final ruleIds = rules.map((r) => r.id).toSet();

  for (final rule in rules) {
    if (!vehicleIds.contains(rule.vehicleId)) {
      throw ImportException(
        ImportErrorCode.fkOrphan,
        'Maintenance rule "${rule.name}" refers to a vehicle that is not '
        'in this archive.',
        file: 'maintenance_rules.csv',
      );
    }
  }
  for (final fillUp in fillUps) {
    if (!vehicleIds.contains(fillUp.vehicleId)) {
      throw ImportException(
        ImportErrorCode.fkOrphan,
        'A fill-up refers to a vehicle that is not in this archive.',
        file: 'fill_ups.csv',
      );
    }
  }
  for (final event in events) {
    if (!vehicleIds.contains(event.vehicleId)) {
      throw ImportException(
        ImportErrorCode.fkOrphan,
        'A maintenance record refers to a vehicle that is not in this '
        'archive.',
        file: 'maintenance_events.csv',
      );
    }
    final ruleId = event.ruleId;
    if (ruleId != null && !ruleIds.contains(ruleId)) {
      throw ImportException(
        ImportErrorCode.fkOrphan,
        'A maintenance record refers to a reminder rule that is not in '
        'this archive.',
        file: 'maintenance_events.csv',
      );
    }
  }
}
