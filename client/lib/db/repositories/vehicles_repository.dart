/// Repository for the `vehicles` table.
///
/// Spec: `docs/specs/data-model.md` §`vehicles` + ADR 002 (protocol
/// columns) + `docs/product/ux/DELIVERY_ACCEPTANCE.md` §"Settings &
/// vehicles" (must-ship list).
///
/// M1 (offline-first) responsibilities:
///   - create / amend / soft-delete / archive vehicles locally,
///   - read live vs archived,
///   - stream live vehicles for the shell selector.
///
/// M3 will layer the outbox-enqueue side-effect on top of these calls;
/// today the repo writes directly to the local table.
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Allowed values for `fuel_type` per `docs/specs/data-model.md`
/// §`vehicles` and the SQL CHECK constraint in
/// `client/lib/db/tables/vehicles.dart`.
enum VehicleFuelType {
  gasoline('gasoline'),
  diesel('diesel'),
  lpg('lpg'),
  cng('cng'),
  evKwh('ev_kwh'),
  other('other');

  const VehicleFuelType(this.wire);

  final String wire;

  static VehicleFuelType fromWire(String wire) {
    for (final t in VehicleFuelType.values) {
      if (t.wire == wire) return t;
    }
    throw ArgumentError.value(wire, 'wire', 'unknown VehicleFuelType');
  }
}

/// Form-time inputs for creating or editing a vehicle. Optional fields
/// are explicit so callers can clear a field by passing `null`.
class VehicleDraft {
  const VehicleDraft({
    required this.name,
    required this.fuelType,
    this.make,
    this.model,
    this.year,
    this.vin,
    this.tankCapacityUL,
  });

  final String name;
  final VehicleFuelType fuelType;
  final String? make;
  final String? model;
  final int? year;
  final String? vin;
  final int? tankCapacityUL;
}

class VehiclesRepository {
  VehiclesRepository(this._db, {String Function()? newId, String Function()? now})
      : _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  // --------------------------------------------------------------- read

  /// Live vehicles only (`deleted_at IS NULL AND archived_at IS NULL`),
  /// ordered by `name ASC` for a stable selector.
  Stream<List<VehicleRow>> watchLive() {
    final query = _db.select(_db.vehicles)
      ..where((v) => v.deletedAt.isNull() & v.archivedAt.isNull())
      ..orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.watch();
  }

  /// One-shot variant used to seed `ActiveVehicle` on launch.
  Future<List<VehicleRow>> liveOnce() {
    final query = _db.select(_db.vehicles)
      ..where((v) => v.deletedAt.isNull() & v.archivedAt.isNull())
      ..orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.get();
  }

  /// All vehicles regardless of soft-delete / archive — for Settings UI
  /// and any "show archived" toggle.
  Stream<List<VehicleRow>> watchAll() {
    final query = _db.select(_db.vehicles)
      ..orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.watch();
  }

  /// Single-row lookup; null on miss. Honors soft-delete (a deleted
  /// row returns null) — matches `FillUpsRepository.findById` so the
  /// UI never has to special-case "row exists but is dead".
  Future<VehicleRow?> findById(String id) {
    final query = _db.select(_db.vehicles)
      ..where((v) => v.id.equals(id) & v.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  // --------------------------------------------------------------- write

  /// Insert a new vehicle row. Returns the generated id so the caller
  /// can immediately set it as the active vehicle.
  Future<String> create(VehicleDraft draft) async {
    final id = _newId();
    await _db.into(_db.vehicles).insert(
          VehiclesCompanion(
            id: Value(id),
            name: Value(draft.name),
            fuelType: Value(draft.fuelType.wire),
            make: Value(draft.make),
            model: Value(draft.model),
            year: Value(draft.year),
            vin: Value(draft.vin),
            tankCapacityUL: Value(draft.tankCapacityUL),
            updatedAt: Value(_now()),
            mutationId: Value(_newId()),
          ),
        );
    return id;
  }

  /// Replace the editable fields on an existing live vehicle. No-op if
  /// the row does not exist or is soft-deleted. Returns `true` when a
  /// row was updated.
  Future<bool> update(String id, VehicleDraft draft) async {
    final updated = await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(id) & v.deletedAt.isNull()))
        .write(
      VehiclesCompanion(
        name: Value(draft.name),
        fuelType: Value(draft.fuelType.wire),
        make: Value(draft.make),
        model: Value(draft.model),
        year: Value(draft.year),
        vin: Value(draft.vin),
        tankCapacityUL: Value(draft.tankCapacityUL),
        updatedAt: Value(_now()),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }

  /// Soft-delete: set `deleted_at` so the row drops out of every live
  /// query but its history stays for math / export. v1 has no hard
  /// delete from the UI per CES-39 acceptance.
  Future<bool> softDelete(String id) async {
    final ts = _now();
    final updated = await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(id) & v.deletedAt.isNull()))
        .write(
      VehiclesCompanion(
        deletedAt: Value(ts),
        updatedAt: Value(ts),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }

  /// Archive: keep the vehicle visible in "show archived" surfaces but
  /// drop it from the active selector. Distinct from soft-delete (the
  /// row is still considered live for math + export).
  Future<bool> archive(String id) async {
    final ts = _now();
    final updated = await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(id) & v.deletedAt.isNull()))
        .write(
      VehiclesCompanion(
        archivedAt: Value(ts),
        updatedAt: Value(ts),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }

  /// Inverse of [archive].
  Future<bool> unarchive(String id) async {
    final ts = _now();
    final updated = await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(id) & v.deletedAt.isNull()))
        .write(
      VehiclesCompanion(
        archivedAt: const Value<String?>(null),
        updatedAt: Value(ts),
        mutationId: Value(_newId()),
      ),
    );
    return updated > 0;
  }
}
