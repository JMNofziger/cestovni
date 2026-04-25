// Active vehicle session state (CES-56).
//
// Source of truth: `docs/product/ux/cestovni-views.md` § *Active
// vehicle (session state)*.
//
// - Live vehicles only: `deleted_at IS NULL AND archived_at IS NULL`,
//   ordered by `name` for a stable selector.
// - "Active" is in-memory session state via [InheritedNotifier]. It
//   persists across tab switches but resets on app cold-start.
// - On launch the first live vehicle is selected; if none exist the
//   selector renders a placeholder (real "Add vehicle" CTA lands
//   with CES-39).
// - When the eventually-added `settings.default_vehicle_id` column
//   exists it should win over the ordering rule above; tracked as a
//   follow-up under CES-39 since the column does not yet exist on
//   `settings` (see `client/lib/db/tables/settings.dart`).

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../db/app_database.dart';

/// Mutable holder for the currently active vehicle id. Notifies
/// listeners (the shell header + tab pages) when the user picks a
/// different vehicle from the selector.
class ActiveVehicle extends ChangeNotifier {
  ActiveVehicle({String? initialId}) : _vehicleId = initialId;

  String? _vehicleId;
  String? get vehicleId => _vehicleId;

  /// Set the active vehicle. No-op if unchanged.
  void setVehicleId(String? id) {
    if (id == _vehicleId) return;
    _vehicleId = id;
    notifyListeners();
  }
}

/// Inherited carrier so descendants can read [ActiveVehicle] without
/// drilling props.
class ActiveVehicleScope extends InheritedNotifier<ActiveVehicle> {
  const ActiveVehicleScope({
    super.key,
    required ActiveVehicle super.notifier,
    required super.child,
  });

  static ActiveVehicle of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ActiveVehicleScope>();
    assert(scope != null, 'ActiveVehicleScope missing from widget tree');
    return scope!.notifier!;
  }
}

/// Repository helper around the `vehicles` table for the shell. Kept
/// thin; CES-39 will introduce a dedicated `VehiclesDao`.
class VehicleRepository {
  VehicleRepository(this._db);

  final AppDatabase _db;

  /// Streams live vehicles ordered by `name`. "Live" = not soft-
  /// deleted, not archived.
  Stream<List<VehicleRow>> watchLiveVehicles() {
    final query = _db.select(_db.vehicles)
      ..where((v) => v.deletedAt.isNull() & v.archivedAt.isNull())
      ..orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.watch();
  }

  /// One-shot lookup of live vehicles, used to seed the active
  /// vehicle on app launch.
  Future<List<VehicleRow>> liveVehiclesOnce() {
    final query = _db.select(_db.vehicles)
      ..where((v) => v.deletedAt.isNull() & v.archivedAt.isNull())
      ..orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.get();
  }
}
