// Active vehicle session state (CES-56) + scope.
//
// Source of truth: `docs/product/ux/cestovni-views.md` § *Active
// vehicle (session state)*.
//
// - "Active" is in-memory session state via [InheritedNotifier]. It
//   persists across tab switches but resets on app cold-start.
// - On launch the first live vehicle is selected; if none exist the
//   selector renders a placeholder (the "Add vehicle" CTA lands with
//   CES-39).
// - `settings.default_vehicle_id` (CES-57) wins over the ordering
//   rule when it still resolves to a live vehicle; see
//   `shell.dart#_seedActiveVehicle`.
//
// The previous inline `VehicleRepository` here moved to
// `client/lib/db/repositories/vehicles_repository.dart` during CES-39
// kickoff. Re-exported below so existing call sites
// (`shell.dart` -> `VehicleRepository`) keep working.

import 'package:flutter/widgets.dart';

import '../db/repositories/vehicles_repository.dart';

export '../db/repositories/vehicles_repository.dart'
    show VehiclesRepository, VehicleDraft, VehicleFuelType;

/// Backwards-compatible alias for the pre-CES-39 inline class so
/// `shell.dart` keeps compiling while the broader vertical lands.
typedef VehicleRepository = VehiclesRepository;

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
