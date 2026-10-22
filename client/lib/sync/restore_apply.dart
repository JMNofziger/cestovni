import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/repositories/protocol_writes.dart';

/// Writes one `GET /changes` page and its cursor in a single transaction.
///
/// A replay of the same `(id, row_version)` is a no-op. A different
/// `row_version` for an id the device already has overwrites the local
/// row (server wins) and drops any pending outbox entry for that id so
/// the pre-restore payload is not pushed back. Rows the server did not
/// send are left alone, including local writes with a null `row_version`.
class RestoreApplier {
  RestoreApplier(this._db, {String Function()? now}) : _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _now;

  Future<int> applyPage({
    required String table,
    required List<Map<String, dynamic>> rows,
    required int nextSince,
  }) async {
    _requireTable(table);
    var wrote = 0;
    await _db.transaction(() async {
      for (final row in rows) {
        if (await _upsert(table, row)) wrote += 1;
      }
      await _db.into(_db.syncCursors).insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              cursorTable: table,
              lastRowVersion: Value(nextSince),
              updatedAt: _now(),
            ),
          );
    });
    return wrote;
  }

  Future<int> cursorFor(String table) async {
    final row = await (_db.select(_db.syncCursors)
          ..where((c) => c.cursorTable.equals(table)))
        .getSingleOrNull();
    return row?.lastRowVersion ?? 0;
  }

  Future<int> syncedCount(String table) async {
    final sqlTable = _requireTable(table);
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM $sqlTable WHERE row_version IS NOT NULL',
    ).getSingle();
    return row.read<int>('c');
  }

  Future<bool> _upsert(String table, Map<String, dynamic> row) async {
    final id = _text(row['id']);
    final version = _int(row['row_version']);
    if (id == null || id.length != 36) {
      throw FormatException('restore row missing id on $table');
    }
    if (version == null) {
      throw FormatException('restore row $id missing row_version');
    }
    if (table == 'settings') {
      await _replaceUnsyncedSettings(id);
    }
    final existing = await _db.customSelect(
      'SELECT row_version FROM ${_requireTable(table)} WHERE id = ?',
      variables: [Variable<String>(id)],
    ).getSingleOrNull();
    if (existing != null && existing.read<int?>('row_version') == version) {
      return false;
    }
    await _db.customStatement(
      'DELETE FROM outbox WHERE "table" = ? AND row_id = ?',
      [table, id],
    );
    final cols = _columns(table, row);
    if (existing == null) {
      await _db.customStatement(
        'INSERT INTO ${_requireTable(table)} (${cols.names}) VALUES (${cols.places})',
        cols.args,
      );
    } else {
      await _db.customStatement(
        'UPDATE ${_requireTable(table)} SET ${cols.assignments} WHERE id = ?',
        [...cols.updateArgs, id],
      );
    }
    return true;
  }

  Future<void> _replaceUnsyncedSettings(String incomingId) async {
    await _db.customStatement(
      'DELETE FROM outbox WHERE "table" = ? AND row_id IN ('
      'SELECT id FROM settings WHERE id != ? AND row_version IS NULL)',
      ['settings', incomingId],
    );
    await _db.customStatement(
      'DELETE FROM settings WHERE id != ? AND row_version IS NULL',
      [incomingId],
    );
  }
}

String _requireTable(String table) {
  switch (table) {
    case 'vehicles':
    case 'fill_ups':
    case 'maintenance_rules':
    case 'maintenance_events':
    case 'settings':
      return table;
    default:
      throw ArgumentError.value(table, 'table', 'not a backed-up table');
  }
}

class _Bound {
  _Bound({
    required this.names,
    required this.places,
    required this.assignments,
    required this.args,
    required this.updateArgs,
  });

  final String names;
  final String places;
  final String assignments;
  final List<Object?> args;
  final List<Object?> updateArgs;
}

_Bound _columns(String table, Map<String, dynamic> row) {
  final fields = <String, Object?>{
    'id': _requiredText(row, 'id'),
    'user_id': _text(row['user_id']),
    'row_version': _requiredInt(row, 'row_version'),
    'updated_at': _requiredText(row, 'updated_at'),
    'deleted_at': _text(row['deleted_at']),
    'mutation_id': _requiredText(row, 'mutation_id'),
    ..._domain(table, row),
  };
  final names = <String>[];
  final places = <String>[];
  final assignments = <String>[];
  final args = <Object?>[];
  for (final entry in fields.entries) {
    final sql = _quote(entry.key);
    names.add(sql);
    places.add('?');
    if (entry.key != 'id') assignments.add('$sql = ?');
    args.add(entry.value);
  }
  final updateArgs = <Object?>[
    for (final entry in fields.entries)
      if (entry.key != 'id') entry.value,
  ];
  return _Bound(
    names: names.join(', '),
    places: places.join(', '),
    assignments: assignments.join(', '),
    args: args,
    updateArgs: updateArgs,
  );
}

Map<String, Object?> _domain(String table, Map<String, dynamic> row) {
  switch (table) {
    case 'vehicles':
      return {
        'name': _requiredText(row, 'name'),
        'make': _text(row['make']),
        'model': _text(row['model']),
        'year': _int(row['year']),
        'vin': _text(row['vin']),
        'fuel_type': _requiredText(row, 'fuel_type'),
        'tank_capacity_uL': _int(row['tank_capacity_uL']),
        'archived_at': _text(row['archived_at']),
      };
    case 'fill_ups':
      return {
        'vehicle_id': _requiredText(row, 'vehicle_id'),
        'filled_at': _requiredText(row, 'filled_at'),
        'odometer_m': _requiredInt(row, 'odometer_m'),
        'volume_uL': _requiredInt(row, 'volume_uL'),
        'total_price_cents': _requiredInt(row, 'total_price_cents'),
        'currency_code': _requiredText(row, 'currency_code'),
        'is_full': _bit(row['is_full']),
        'missed_before': _bit(row['missed_before']),
        'odometer_reset': _bit(row['odometer_reset']),
        'notes': _text(row['notes']),
      };
    case 'maintenance_rules':
      return {
        'vehicle_id': _requiredText(row, 'vehicle_id'),
        'name': _requiredText(row, 'name'),
        'cadence_m': _int(row['cadence_m']),
        'cadence_days': _int(row['cadence_days']),
        'enabled': _bit(row['enabled'], fallback: 1),
        'notes': _text(row['notes']),
      };
    case 'maintenance_events':
      return {
        'vehicle_id': _requiredText(row, 'vehicle_id'),
        'rule_id': _text(row['rule_id']),
        'performed_at': _requiredText(row, 'performed_at'),
        'odometer_m': _int(row['odometer_m']),
        'cost_cents': _int(row['cost_cents']) ?? 0,
        'currency_code': _requiredText(row, 'currency_code'),
        'category': _text(row['category']) ?? 'other',
        'shop': _text(row['shop']),
        'notes': _text(row['notes']),
      };
    case 'settings':
      return {
        'preferred_distance_unit': _requiredText(row, 'preferred_distance_unit'),
        'preferred_volume_unit': _requiredText(row, 'preferred_volume_unit'),
        'currency_code': _requiredText(row, 'currency_code'),
        'timezone': _requiredText(row, 'timezone'),
        'default_vehicle_id': _text(row['default_vehicle_id']),
      };
    default:
      throw ArgumentError.value(table, 'table');
  }
}

String _quote(String name) {
  if (name == 'tank_capacity_uL' || name == 'volume_uL') return '"$name"';
  return name;
}

String _requiredText(Map<String, dynamic> row, String key) {
  final value = _text(row[key]);
  if (value == null || value.isEmpty) {
    throw FormatException('restore row missing $key');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> row, String key) {
  final value = _int(row[key]);
  if (value == null) throw FormatException('restore row missing $key');
  return value;
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value.toString();
}

int? _int(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int _bit(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value == 0 ? 0 : 1;
  final text = value.toString().toLowerCase();
  if (text == 'true' || text == 't' || text == '1') return 1;
  if (text == 'false' || text == 'f' || text == '0') return 0;
  return fallback;
}
