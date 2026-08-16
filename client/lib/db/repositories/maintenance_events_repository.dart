/// Repository for `maintenance_events` + linked `maintenance_rules`.
///
/// Spec: `docs/specs/data-model.md` §`maintenance_events` /
/// §`maintenance_rules` + `docs/product/ux/DATA_CONTRACTS.md`
/// §"Maintenance entry contract".
///
/// Local-only for CES-67: no outbox enqueue (vehicles/settings/maint
/// outbox is M3 / CES-44). Soft-delete is still used so History and
/// export can honor `deleted_at`.
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Closed category enum — keep in lockstep with the SQLite CHECK on
/// `maintenance_events.category` and DATA_CONTRACTS.md.
const List<String> maintenanceCategories = [
  'oil',
  'tires',
  'brakes',
  'inspection',
  'battery',
  'fluid',
  'other',
];

String maintenanceCategoryLabel(String category) => switch (category) {
      'oil' => 'Oil',
      'tires' => 'Tires',
      'brakes' => 'Brakes',
      'inspection' => 'Inspection',
      'battery' => 'Battery',
      'fluid' => 'Fluid',
      'other' => 'Other',
      _ => category,
    };

/// Form-time inputs for inserting a maintenance event.
///
/// Canonical SI-INT64: [odometerM] meters (nullable), [costCents]
/// (blank form → 0). [performedAt] is already the stored UTC instant.
class MaintenanceEventDraft {
  const MaintenanceEventDraft({
    required this.vehicleId,
    required this.performedAt,
    required this.category,
    required this.costCents,
    required this.currencyCode,
    this.odometerM,
    this.shop,
    this.notes,
    this.ruleId,
  });

  final String vehicleId;
  final DateTime performedAt;
  final String category;
  final int costCents;
  final String currencyCode;
  final int? odometerM;
  final String? shop;
  final String? notes;
  final String? ruleId;
}

/// Reminder cadence fields persisted on `maintenance_rules`.
///
/// At least one of [cadenceKmMeters] / [cadenceDays] must be non-null
/// (table CHECK). [cadenceKmMeters] is canonical meters despite the
/// SQL column name `cadence_km`. Months in the form map to
/// `cadence_days = months * 30`.
class MaintenanceRuleDraft {
  const MaintenanceRuleDraft({
    required this.vehicleId,
    required this.name,
    this.cadenceKmMeters,
    this.cadenceDays,
    this.notes,
  });

  final String vehicleId;
  final String name;
  final int? cadenceKmMeters;
  final int? cadenceDays;
  final String? notes;
}

class MaintenanceEventsRepository {
  MaintenanceEventsRepository(
    AppDatabase db, {
    String Function()? newId,
    String Function()? now,
  })  : _db = db,
        _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  // --------------------------------------------------------------- read

  /// Live events for one vehicle, newest first.
  Stream<List<MaintenanceEventRow>> watchForVehicle(String vehicleId) {
    final query = _db.select(_db.maintenanceEvents)
      ..where((e) => e.vehicleId.equals(vehicleId) & e.deletedAt.isNull())
      ..orderBy([
        (e) => OrderingTerm.desc(e.performedAt),
        (e) => OrderingTerm.desc(e.id),
      ]);
    return query.watch();
  }

  Future<List<MaintenanceEventRow>> listForVehicle(String vehicleId) {
    final query = _db.select(_db.maintenanceEvents)
      ..where((e) => e.vehicleId.equals(vehicleId) & e.deletedAt.isNull())
      ..orderBy([
        (e) => OrderingTerm.desc(e.performedAt),
        (e) => OrderingTerm.desc(e.id),
      ]);
    return query.get();
  }

  Future<MaintenanceEventRow?> findById(String id) {
    final query = _db.select(_db.maintenanceEvents)
      ..where((e) => e.id.equals(id) & e.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  /// Live rule for [vehicleId] whose [name] matches (typically the
  /// category key). Used to prefill reminder fields.
  Future<MaintenanceRuleRow?> findRuleByVehicleAndName(
    String vehicleId,
    String name,
  ) {
    final query = _db.select(_db.maintenanceRules)
      ..where(
        (r) =>
            r.vehicleId.equals(vehicleId) &
            r.name.equals(name) &
            r.deletedAt.isNull(),
      );
    return query.getSingleOrNull();
  }

  // --------------------------------------------------------------- write

  /// Insert a maintenance event. Returns the new id.
  Future<String> create(MaintenanceEventDraft draft) async {
    _assertCategory(draft.category);
    final String id = _newId();
    final String updatedAt = _now();
    await _db.into(_db.maintenanceEvents).insert(
          MaintenanceEventsCompanion(
            id: Value(id),
            vehicleId: Value(draft.vehicleId),
            ruleId: Value(draft.ruleId),
            performedAt: Value(draft.performedAt.toUtc().toIso8601String()),
            odometerM: Value(draft.odometerM),
            costCents: Value(draft.costCents),
            currencyCode: Value(draft.currencyCode),
            category: Value(draft.category),
            shop: Value(_blankToNull(draft.shop, max: 120)),
            notes: Value(_blankToNull(draft.notes, max: 500)),
            updatedAt: Value(updatedAt),
            mutationId: Value(_newId()),
          ),
        );
    return id;
  }

  /// Soft-delete: set `deleted_at`. Returns true if a live row was
  /// updated.
  Future<bool> softDelete(String id) async {
    final String ts = _now();
    final int wrote = await (_db.update(_db.maintenanceEvents)
          ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
        .write(
      MaintenanceEventsCompanion(
        deletedAt: Value(ts),
        updatedAt: Value(ts),
        mutationId: Value(_newId()),
      ),
    );
    return wrote > 0;
  }

  /// Create or update the reminder rule for [draft.name] on this
  /// vehicle. Returns the rule id. Requires at least one cadence.
  Future<String> upsertReminderRule(MaintenanceRuleDraft draft) async {
    if (draft.cadenceKmMeters == null && draft.cadenceDays == null) {
      throw ArgumentError(
        'Reminder rule needs cadenceKmMeters and/or cadenceDays',
      );
    }
    final MaintenanceRuleRow? existing =
        await findRuleByVehicleAndName(draft.vehicleId, draft.name);
    final String updatedAt = _now();
    if (existing != null) {
      await (_db.update(_db.maintenanceRules)
            ..where((r) => r.id.equals(existing.id)))
          .write(
        MaintenanceRulesCompanion(
          cadenceKm: Value(draft.cadenceKmMeters),
          cadenceDays: Value(draft.cadenceDays),
          notes: Value(_blankToNull(draft.notes, max: 500)),
          enabled: const Value(true),
          updatedAt: Value(updatedAt),
          mutationId: Value(_newId()),
        ),
      );
      return existing.id;
    }
    final String id = _newId();
    await _db.into(_db.maintenanceRules).insert(
          MaintenanceRulesCompanion(
            id: Value(id),
            vehicleId: Value(draft.vehicleId),
            name: Value(draft.name),
            cadenceKm: Value(draft.cadenceKmMeters),
            cadenceDays: Value(draft.cadenceDays),
            enabled: const Value(true),
            notes: Value(_blankToNull(draft.notes, max: 500)),
            updatedAt: Value(updatedAt),
            mutationId: Value(_newId()),
          ),
        );
    return id;
  }

  static void _assertCategory(String category) {
    if (!maintenanceCategories.contains(category)) {
      throw ArgumentError.value(category, 'category', 'not in closed enum');
    }
  }

  static String? _blankToNull(String? value, {required int max}) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > max) return trimmed.substring(0, max);
    return trimmed;
  }
}
