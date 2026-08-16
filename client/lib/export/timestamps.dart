/// UTC / local timestamp formatting for export CSV columns.
///
/// Spec: ISO-8601 UTC with `_utc` suffix; `_local` is civil time in
/// `settings.timezone`. There is no tz database on the client yet
/// (same approximation as CES-66): when the IANA name is UTC we emit
/// UTC civil time; otherwise we use the device offset.
library;

/// Format a stored ISO timestamp as `YYYY-MM-DDTHH:MM:SSZ`.
String formatUtcIso(String stored) {
  final DateTime dt = DateTime.parse(stored).toUtc();
  return '${_civil(dt)}Z';
}

/// Civil local time `YYYY-MM-DDTHH:MM:SS` (no offset) for [stored]
/// interpreted as UTC, converted via [ianaTimezone].
String formatLocalIso(String stored, String ianaTimezone) {
  final DateTime utc = DateTime.parse(stored).toUtc();
  final DateTime civil = _isUtc(ianaTimezone) ? utc : utc.toLocal();
  return _civil(civil);
}

bool _isUtc(String tz) =>
    tz == 'UTC' || tz == 'Etc/UTC' || tz == 'Etc/GMT' || tz == 'GMT';

String _civil(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${two(dt.month)}-${two(dt.day)}T'
      '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

/// `exported_at_utc` / filename timestamp: second-precision UTC.
String formatExportedAt(DateTime utc) => formatUtcIso(utc.toUtc().toIso8601String());

/// Filename stamp `YYYYMMDD_HHMMSS` in UTC.
String formatFilenameTimestamp(DateTime utc) {
  final DateTime dt = utc.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year.toString().padLeft(4, '0')}'
      '${two(dt.month)}${two(dt.day)}_'
      '${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
}
