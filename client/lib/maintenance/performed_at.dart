/// Date-only `performed_at` encoding (CES-67 / CES-54).
///
/// Spec: `docs/product/ux/DATA_CONTRACTS.md` §"Performed time
/// (maintenance)". The user picks a civil date; we store a UTC instant
/// at **12:00:00.000** in `settings.timezone` so the calendar day is
/// stable (no phantom shift from naive `00:00Z`, no DST missing
/// midnight). Display must not show a clock for date-only rows.
///
/// Timezone resolution matches CES-66 Metrics: `UTC` is exact; other
/// IANA names approximate with the device offset until a tz database
/// lands. Pure Dart — no Flutter or Drift.
library;

/// Inclusive offset of [timezone] from UTC for civil-date math.
///
/// `UTC` → zero. Anything else → the device's current offset (same
/// approximation as `metrics_page.dart#_tzOffset`).
Duration tzOffsetForSettings(String timezone) =>
    timezone == 'UTC' ? Duration.zero : DateTime.now().timeZoneOffset;

/// Civil date (year/month/day only) → stored UTC instant at local noon.
DateTime dateOnlyToPerformedAtUtc(
  DateTime civilDate, {
  Duration tzOffset = Duration.zero,
}) {
  final DateTime noonLocal = DateTime.utc(
    civilDate.year,
    civilDate.month,
    civilDate.day,
    12,
  );
  return noonLocal.subtract(tzOffset);
}

/// Stored UTC instant → civil date in the user's timezone (date only).
DateTime performedAtUtcToCivilDate(
  DateTime performedAtUtc, {
  Duration tzOffset = Duration.zero,
}) {
  final DateTime local = performedAtUtc.toUtc().add(tzOffset);
  return DateTime.utc(local.year, local.month, local.day);
}

/// ISO-8601 UTC string for a date-only write.
String dateOnlyToPerformedAtIso(
  DateTime civilDate, {
  Duration tzOffset = Duration.zero,
}) =>
    dateOnlyToPerformedAtUtc(civilDate, tzOffset: tzOffset).toIso8601String();
