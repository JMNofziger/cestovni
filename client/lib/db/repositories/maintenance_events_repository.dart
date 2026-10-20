/// Repository for `maintenance_events` + linked `maintenance_rules`.
///
/// Spec: `docs/specs/data-model.md` §`maintenance_events` /
/// §`maintenance_rules` + `docs/product/ux/DATA_CONTRACTS.md`
/// §"Maintenance entry contract".
///
/// Event and rule writes enqueue to the outbox in the same Drift
/// transaction as the local row. Pass `enqueue: false` in tests that
/// must not queue a backup row.
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'outbox_repository.dart';
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
/// At least one of [cadenceMeters] / [cadenceDays] must be non-null
/// (table CHECK). [cadenceMeters] is canonical meters
/// (`maintenance_rules.cadence_m`). Months in the form map to
/// `cadence_days = months * 30`.
class MaintenanceRuleDraft {
  const MaintenanceRuleDraft({
    required this.vehicleId,
    required this.name,
    this.cadenceMeters,
    this.cadenceDays,
    this.notes,
  });

  final String vehicleId;
  final String name;
  final int? cadenceMeters;
  final int? cadenceDays;
  final String? notes;
}

class MaintenanceEventsRepository {
  MaintenanceEventsRepository(
    AppDatabase db, {
    String Function()? newId,
    String Function()? now,
    OutboxRepository? outbox,
    bool enqueue = true,
  })  : _db = db,
        _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc,
        _outbox = enqueue
            ? (outbox ?? OutboxRepository(db, newId: newId, now: now))
            : null;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;
  final OutboxRepository? _outbox;

  static const String eventsTable = 'maintenance_events';
  static const String rulesTable = 'maintenance_rules';

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
    final String mutationId = _newId();
    await _db.transaction(() async {
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
              mutationId: Value(mutationId),
            ),
          );
      final row = await _event(id);
      await _enqueue(eventsTable, row!, insert: true);
    });
    return id;
  }

  /// Soft-delete: set `deleted_at`. Returns true if a live row was
  /// updated.
  Future<bool> softDelete(String id) async {
    final String ts = _now();
    return _db.transaction(() async {
      final int wrote = await (_db.update(_db.maintenanceEvents)
            ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
          .write(
        MaintenanceEventsCompanion(
          deletedAt: Value(ts),
          updatedAt: Value(ts),
          mutationId: Value(_newId()),
        ),
      );
      if (wrote == 0) return false;
      await _outbox?.enqueueSoftDelete(table: eventsTable, rowId: id);
      return true;
    });
  }

  /// Create or update the reminder rule for [draft.name] on this
  /// vehicle. Returns the rule id. Requires at least one cadence.
  ///
  /// A new rule enqueues `insert`. An existing rule enqueues `update`.
  /// [OutboxRepository.enqueueUpdate] coalesces into a still-pending
  /// insert for the same row.
  Future<String> upsertReminderRule(MaintenanceRuleDraft draft) async {
    if (draft.cadenceMeters == null && draft.cadenceDays == null) {
      throw ArgumentError(
        'Reminder rule needs cadenceMeters and/or cadenceDays',
      );
    }
    return _db.transaction(() async {
      final MaintenanceRuleRow? existing =
          await findRuleByVehicleAndName(draft.vehicleId, draft.name);
      final String updatedAt = _now();
      if (existing != null) {
        await (_db.update(_db.maintenanceRules)
              ..where((r) => r.id.equals(existing.id)))
            .write(
          MaintenanceRulesCompanion(
            cadenceM: Value(draft.cadenceMeters),
            cadenceDays: Value(draft.cadenceDays),
            notes: Value(_blankToNull(draft.notes, max: 500)),
            enabled: const Value(true),
            updatedAt: Value(updatedAt),
            mutationId: Value(_newId()),
          ),
        );
        final row = await _rule(existing.id);
        await _enqueue(rulesTable, row!, insert: false);
        return existing.id;
      }
      final String id = _newId();
      await _db.into(_db.maintenanceRules).insert(
            MaintenanceRulesCompanion(
              id: Value(id),
              vehicleId: Value(draft.vehicleId),
              name: Value(draft.name),
              cadenceM: Value(draft.cadenceMeters),
              cadenceDays: Value(draft.cadenceDays),
              enabled: const Value(true),
              notes: Value(_blankToNull(draft.notes, max: 500)),
              updatedAt: Value(updatedAt),
              mutationId: Value(_newId()),
            ),
          );
      final row = await _rule(id);
      await _enqueue(rulesTable, row!, insert: true);
      return id;
    });
  }

  Future<MaintenanceEventRow?> _event(String id) {
    final query = _db.select(_db.maintenanceEvents)
      ..where((e) => e.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<MaintenanceRuleRow?> _rule(String id) {
    final query = _db.select(_db.maintenanceRules)
      ..where((r) => r.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> _enqueue(String table, dynamic row, {required bool insert}) async {
    final box = _outbox;
    if (box == null) return;
    final String id = row.id as String;
    final payload = table == eventsTable
        ? _eventPayload(row as MaintenanceEventRow)
        : _rulePayload(row as MaintenanceRuleRow);
    if (insert) {
      await box.enqueueInsert(table: table, rowId: id, payload: payload);
    } else {
      await box.enqueueUpdate(table: table, rowId: id, payload: payload);
    }
  }

  Map<String, dynamic> _eventPayload(MaintenanceEventRow row) {
    return <String, dynamic>{
      'id': row.id,
      'vehicle_id': row.vehicleId,
      'rule_id': row.ruleId,
      'performed_at': row.performedAt,
      'odometer_m': row.odometerM,
      'cost_cents': row.costCents,
      'currency_code': row.currencyCode,
      'category': row.category,
      'shop': row.shop,
      'notes': row.notes,
      'updated_at': row.updatedAt,
      'deleted_at': row.deletedAt,
      'mutation_id': row.mutationId,
    };
  }

  Map<String, dynamic> _rulePayload(MaintenanceRuleRow row) {
    return <String, dynamic>{
      'id': row.id,
      'vehicle_id': row.vehicleId,
      'name': row.name,
      'cadence_m': row.cadenceM,
      'cadence_days': row.cadenceDays,
      'enabled': row.enabled,
      'notes': row.notes,
      'updated_at': row.updatedAt,
      'deleted_at': row.deletedAt,
      'mutation_id': row.mutationId,
    };
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
