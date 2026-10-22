import 'dart:convert';

import '../db/app_database.dart';

const _months = <String>[
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
];

/// Human summary for Settings → Backup. Local UI only — not telemetry.
String deadLetterSummary(OutboxRow row) {
  final payload = _payload(row);
  switch (row.table_) {
    case 'fill_ups':
      final day = _dayLabel(payload?['filled_at']);
      if (day != null) {
        return "Fill-up on $day couldn't be backed up — server rejected it";
      }
      return "A fill-up couldn't be backed up — server rejected it";
    case 'vehicles':
      final name = payload?['name'];
      if (name is String && name.trim().isNotEmpty) {
        return "Vehicle ${name.trim()} couldn't be backed up — server rejected it";
      }
      return "A vehicle couldn't be backed up — server rejected it";
    case 'settings':
      return "Settings couldn't be backed up — server rejected it";
    case 'maintenance_events':
      return "A maintenance entry couldn't be backed up — server rejected it";
    case 'maintenance_rules':
      return "A maintenance reminder couldn't be backed up — server rejected it";
    default:
      return "A change couldn't be backed up — server rejected it";
  }
}

String backupTableLabel(String table) {
  switch (table) {
    case 'vehicles':
      return 'Vehicle';
    case 'fill_ups':
      return 'Fill-up';
    case 'maintenance_rules':
      return 'Maintenance reminder';
    case 'maintenance_events':
      return 'Maintenance entry';
    case 'settings':
      return 'Settings';
    default:
      return table;
  }
}

Map<String, dynamic>? _payload(OutboxRow row) {
  final raw = row.payloadJson;
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

String? _dayLabel(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return '${_months[parsed.toUtc().month - 1]} ${parsed.toUtc().day}';
}
