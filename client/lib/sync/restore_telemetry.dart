import 'package:flutter/foundation.dart';

/// CES-45 stubs for `restore_start` / `restore_result`.
///
/// CES-46 will replace this with `Telemetry.emit`. The names and
/// property values match `docs/specs/telemetry-events.v1.yaml`. This
/// function must not call `Telemetry.emit` — the CI gate would then
/// require a wired client that does not exist yet.
void restoreTelemetry(String name, Map<String, String> properties) {
  assert(
    name == 'restore_start' || name == 'restore_result',
    'unknown restore telemetry event: $name',
  );
  if (kDebugMode) {
    final body = properties.entries.map((e) => '${e.key}=${e.value}').join(' ');
    debugPrint('telemetry $name $body');
  }
}

String restoreDurationBucket(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 5) return 'lt_5';
  if (seconds < 30) return 'lt_30';
  if (seconds < 120) return 'lt_120';
  return 'ge_120';
}

String restoreRowsBucket(int rows) {
  if (rows < 100) return 'lt_100';
  if (rows < 1000) return 'lt_1000';
  if (rows < 10000) return 'lt_10000';
  return 'ge_10000';
}
