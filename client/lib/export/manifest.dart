/// `manifest.json` builder (CES-41).
///
/// Spec: `docs/specs/export-v1.md`. `photos_in_export` is the CES-40
/// constant. `max_row_version_seen` is JSON `null` until M3.
library;

import 'dart:convert';

import '../photos/photo_export_guard.dart';

const int exportSchemaVersion = 1;

Map<String, Object?> exportManifest({
  required String exportedAtUtc,
  required String appVersion,
  required String appPlatform,
  required String timezone,
  required String userKeyHash,
  required String preferredDistanceUnit,
  required String preferredVolumeUnit,
  required String currencyCode,
  required int vehiclesCount,
  required int fillUpsCount,
  required int maintenanceRulesCount,
  required int maintenanceEventsCount,
  required int settingsCount,
  required int outboxPendingCount,
  required String? outboxPendingHash,
}) {
  return <String, Object?>{
    'schema_version': exportSchemaVersion,
    'exported_at_utc': exportedAtUtc,
    'app_version': appVersion,
    'app_platform': appPlatform,
    'timezone': timezone,
    'user_key_hash': userKeyHash,
    'unit_preferences': <String, String>{
      'distance': preferredDistanceUnit,
      'volume': preferredVolumeUnit,
      'currency': currencyCode,
    },
    'row_counts': <String, int>{
      'vehicles': vehiclesCount,
      'fill_ups': fillUpsCount,
      'maintenance_rules': maintenanceRulesCount,
      'maintenance_events': maintenanceEventsCount,
      'settings': settingsCount,
    },
    'outbox_pending_count': outboxPendingCount,
    'outbox_pending_hash': outboxPendingHash,
    'photos_in_export': photosInExport,
    'max_row_version_seen': null,
  };
}

String encodeManifest(Map<String, Object?> manifest) =>
    const JsonEncoder.withIndent('  ').convert(manifest) + '\n';
