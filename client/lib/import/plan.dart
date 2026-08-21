/// Validated, DB-free representation of an export ZIP (CES-70).
///
/// Spec: `docs/specs/export-import.md` § Suggested layout — `plan.dart`
/// holds parsed + validated rows, counts and warnings, and knows nothing
/// about Drift. `apply.dart` maps these models onto companions.
///
/// Only **canonical** columns appear here. Derived columns
/// (`odometer_km`, `volume_L`, `*_major`, …) and `*_local` timestamps are
/// required to be present in the header but their values are never read,
/// so there is deliberately nowhere to put them.
///
/// Pure module: no Flutter, no Drift, no `dart:io`.
library;

import 'import_errors.dart';

class ImportedVehicle {
  const ImportedVehicle({
    required this.id,
    required this.name,
    required this.fuelType,
    required this.updatedAt,
    this.make,
    this.model,
    this.year,
    this.vin,
    this.tankCapacityUL,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String fuelType;
  final String updatedAt;
  final String? make;
  final String? model;
  final int? year;
  final String? vin;
  final int? tankCapacityUL;
  final String? archivedAt;
}

class ImportedFillUp {
  const ImportedFillUp({
    required this.id,
    required this.vehicleId,
    required this.filledAt,
    required this.odometerM,
    required this.volumeUL,
    required this.totalPriceCents,
    required this.currencyCode,
    required this.isFull,
    required this.missedBefore,
    required this.odometerReset,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final String filledAt;
  final int odometerM;
  final int volumeUL;
  final int totalPriceCents;
  final String currencyCode;
  final bool isFull;
  final bool missedBefore;
  final bool odometerReset;
  final String updatedAt;
  final String? notes;
}

class ImportedMaintenanceRule {
  const ImportedMaintenanceRule({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.enabled,
    required this.updatedAt,
    this.cadenceMeters,
    this.cadenceDays,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final String name;

  /// The `cadence_km` column, which carries canonical **meters** despite
  /// its name (`export-v1.md` § A3). Imported verbatim, never converted.
  /// Named `cadenceMeters` here so no caller can misread it; the column
  /// name is restored in `apply.dart`.
  final int? cadenceMeters;

  final int? cadenceDays;
  final bool enabled;
  final String updatedAt;
  final String? notes;
}

class ImportedMaintenanceEvent {
  const ImportedMaintenanceEvent({
    required this.id,
    required this.vehicleId,
    required this.performedAt,
    required this.costCents,
    required this.currencyCode,
    required this.category,
    required this.updatedAt,
    this.ruleId,
    this.odometerM,
    this.shop,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final String? ruleId;
  final String performedAt;
  final int? odometerM;
  final int costCents;
  final String currencyCode;
  final String category;
  final String? shop;
  final String? notes;
  final String updatedAt;
}

/// The single `settings` row. Carries no `id`: export omits it because it
/// equals the user id, which is exactly what makes local identity safe to
/// preserve on import.
class ImportedSettings {
  const ImportedSettings({
    required this.preferredDistanceUnit,
    required this.preferredVolumeUnit,
    required this.currencyCode,
    required this.timezone,
    required this.updatedAt,
    this.defaultVehicleId,
  });

  final String preferredDistanceUnit;
  final String preferredVolumeUnit;
  final String currencyCode;
  final String timezone;
  final String? defaultVehicleId;
  final String updatedAt;
}

/// `manifest.json`, after the gates in `validate.dart` have passed.
class ImportedManifest {
  const ImportedManifest({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.appVersion,
    required this.appPlatform,
    required this.timezone,
    required this.userKeyHash,
    required this.outboxPendingCount,
    required this.rowCounts,
  });

  final int schemaVersion;
  final String exportedAtUtc;
  final String appVersion;
  final String appPlatform;
  final String timezone;
  final String userKeyHash;
  final int outboxPendingCount;
  final Map<String, int> rowCounts;
}

/// Everything needed to apply an import, plus everything needed to
/// describe it to the user first. Building a plan performs **no** writes.
class ImportPlan {
  ImportPlan({
    required this.manifest,
    required this.vehicles,
    required this.fillUps,
    required this.maintenanceRules,
    required this.maintenanceEvents,
    required this.settings,
    required this.warnings,
  });

  final ImportedManifest manifest;
  final List<ImportedVehicle> vehicles;
  final List<ImportedFillUp> fillUps;
  final List<ImportedMaintenanceRule> maintenanceRules;
  final List<ImportedMaintenanceEvent> maintenanceEvents;
  final ImportedSettings settings;
  final List<ImportWarning> warnings;

  /// Incoming row counts, keyed by table name.
  Map<String, int> get incomingCounts => <String, int>{
        'vehicles': vehicles.length,
        'fill_ups': fillUps.length,
        'maintenance_rules': maintenanceRules.length,
        'maintenance_events': maintenanceEvents.length,
        'settings': 1,
      };

  int get totalIncomingRows =>
      vehicles.length +
      fillUps.length +
      maintenanceRules.length +
      maintenanceEvents.length;

  /// Vehicle ids the archive brings. Used to reconcile local drafts and
  /// to validate `settings.default_vehicle_id`.
  Set<String> get vehicleIds => vehicles.map((v) => v.id).toSet();
}
