/// Shared DB scaffolding for the receipt-photo tests.
library;

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:drift/native.dart';

AppDatabase openDb() => AppDatabase.withExecutor(NativeDatabase.memory());

/// A vehicle and its open draft. `photo_refs.draft_id` is a foreign key, and
/// v1 allows one open draft per vehicle, so a test needing several drafts
/// needs several vehicles.
class SeededDraft {
  const SeededDraft({required this.vehicleId, required this.draftId});

  final String vehicleId;
  final String draftId;
}

Future<SeededDraft> seedDraft(AppDatabase db, {String name = 'Test Car'}) async {
  final vehicleId = await VehiclesRepository(db).create(VehicleDraft(
    name: name,
    fuelType: VehicleFuelType.gasoline,
  ));
  final draftId =
      await DraftsRepository(db).save(DraftSnapshot(vehicleId: vehicleId));
  return SeededDraft(vehicleId: vehicleId, draftId: draftId);
}
