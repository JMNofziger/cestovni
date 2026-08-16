import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/maintenance_events_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';

/// Known fixture used by the golden ZIP test.
class GoldenSeed {
  GoldenSeed({
    required this.vehicleId,
    required this.fillUpId,
    required this.ruleId,
    required this.eventId,
    required this.settings,
  });

  final String vehicleId;
  final String fillUpId;
  final String ruleId;
  final String eventId;
  final SettingsRow settings;
}

Future<GoldenSeed> seedGoldenExport(AppDatabase db) async {
  final settingsRepo = SettingsRepository(db);
  await settingsRepo.getOrBootstrap();

  final vehicleId = await VehiclesRepository(db).create(
    const VehicleDraft(
      name: 'Octavia',
      fuelType: VehicleFuelType.gasoline,
      make: 'Skoda',
      model: 'Mk3',
      year: 2018,
      tankCapacityUL: 55000000,
    ),
  );

  await settingsRepo.update(timezone: 'UTC', defaultVehicleId: vehicleId);
  final settings = await settingsRepo.getOrBootstrap();

  final fillUpId = await FillUpsRepository(db).create(
    FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 8, 1, 10, 30, 0),
      odometerM: 120000000,
      volumeUL: 42000000,
      totalPriceCents: 6100,
      currencyCode: 'EUR',
      isFull: true,
      notes: 'hello, "world"',
    ),
  );

  final maint = MaintenanceEventsRepository(db);
  final ruleId = await maint.upsertReminderRule(
    MaintenanceRuleDraft(
      vehicleId: vehicleId,
      name: 'oil',
      cadenceKmMeters: 10000000,
      cadenceDays: 365,
      notes: 'every 10k km',
    ),
  );
  final eventId = await maint.create(
    MaintenanceEventDraft(
      vehicleId: vehicleId,
      performedAt: DateTime.utc(2026, 7, 15, 12, 0, 0),
      category: 'oil',
      costCents: 8900,
      currencyCode: 'EUR',
      odometerM: 115000000,
      shop: 'Bosch, Praha',
      notes: 'filter too',
      ruleId: ruleId,
    ),
  );

  return GoldenSeed(
    vehicleId: vehicleId,
    fillUpId: fillUpId,
    ruleId: ruleId,
    eventId: eventId,
    settings: settings,
  );
}
