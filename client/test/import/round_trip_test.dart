import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:cestovni/import/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';
import '../export/_seed.dart';
import '_zip.dart';

void main() {
  test('1 golden round-trip: canonical columns equal row for row', () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    final seed = await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    final destSettings = await SettingsRepository(dest).getOrBootstrap();

    await importZip(dest, zip);

    final vehicles = await dest.select(dest.vehicles).get();
    expect(vehicles, hasLength(1));
    final vehicle = vehicles.single;
    expect(vehicle.id, seed.vehicleId);
    expect(vehicle.name, 'Octavia');
    expect(vehicle.make, 'Skoda');
    expect(vehicle.model, 'Mk3');
    expect(vehicle.year, 2018);
    expect(vehicle.fuelType, 'gasoline');
    expect(vehicle.tankCapacityUL, 55000000);
    expect(vehicle.rowVersion, isNull);

    final fills = await dest.select(dest.fillUps).get();
    expect(fills, hasLength(1));
    final fill = fills.single;
    expect(fill.id, seed.fillUpId);
    expect(fill.vehicleId, seed.vehicleId);
    expect(fill.odometerM, 120000000);
    expect(fill.volumeUL, 42000000);
    expect(fill.totalPriceCents, 6100);
    expect(fill.currencyCode, 'EUR');
    expect(fill.isFull, isTrue);
    expect(fill.notes, 'hello, "world"');
    expect(fill.rowVersion, isNull);

    final rules = await dest.select(dest.maintenanceRules).get();
    expect(rules, hasLength(1));
    final rule = rules.single;
    expect(rule.id, seed.ruleId);
    expect(rule.cadenceKm, 10000000, reason: 'cadence_km is meters, verbatim');
    expect(rule.cadenceDays, 365);
    expect(rule.rowVersion, isNull);

    final events = await dest.select(dest.maintenanceEvents).get();
    expect(events, hasLength(1));
    final event = events.single;
    expect(event.id, seed.eventId);
    expect(event.category, 'oil');
    expect(event.shop, 'Bosch, Praha');
    expect(event.costCents, 8900);
    expect(event.rowVersion, isNull);

    final settings = await SettingsRepository(dest).getOrBootstrap();
    expect(settings.id, destSettings.id, reason: 'local identity preserved');
    expect(settings.timezone, 'UTC');
    expect(settings.defaultVehicleId, seed.vehicleId);
  });

  test('2 idempotency: importing the same ZIP twice is a no-op', () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();

    await importZip(dest, zip);
    final once = await historyFingerprint(dest);
    await importZip(dest, zip, confirmation: importConfirmationKeyword);
    expect(await historyFingerprint(dest), once);

    final ids = (await dest.select(dest.fillUps).get()).map((r) => r.id);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('5 derived columns are unread: corrupt odometer_km keeps odometer_m',
      () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final entries = unpackZip(await exportDbToZip(source));
    entries['fill_ups.csv'] = mutateCsvCell(
      csv: entries['fill_ups.csv']!,
      file: 'fill_ups.csv',
      dataRow: 0,
      column: 'odometer_km',
      value: '999999',
    );

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await importZip(dest, packZip(entries));

    final fill = (await dest.select(dest.fillUps).get()).single;
    expect(fill.odometerM, 120000000);
  });

  test('6 cadence_km = 10000 stores 10000 meters, not 10 or 1e7', () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final entries = unpackZip(await exportDbToZip(source));
    entries['maintenance_rules.csv'] = mutateCsvCell(
      csv: entries['maintenance_rules.csv']!,
      file: 'maintenance_rules.csv',
      dataRow: 0,
      column: 'cadence_km',
      value: '10000',
    );

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await importZip(dest, packZip(entries));

    final rule = (await dest.select(dest.maintenanceRules).get()).single;
    expect(rule.cadenceKm, 10000);
    expect(rule.cadenceKm, isNot(10));
    expect(rule.cadenceKm, isNot(10000000));
  });

  test('9 imported rows have row_version IS NULL and nothing is enqueued',
      () async {
    final source = openInMemoryDb();
    addTearDown(source.close);
    await seedGoldenExport(source);
    final zip = await exportDbToZip(source);

    final dest = openInMemoryDb();
    addTearDown(dest.close);
    await SettingsRepository(dest).getOrBootstrap();
    await importZip(dest, zip);

    for (final row in await dest.select(dest.vehicles).get()) {
      expect(row.rowVersion, isNull);
    }
    for (final row in await dest.select(dest.fillUps).get()) {
      expect(row.rowVersion, isNull);
    }
    for (final row in await dest.select(dest.maintenanceRules).get()) {
      expect(row.rowVersion, isNull);
    }
    for (final row in await dest.select(dest.maintenanceEvents).get()) {
      expect(row.rowVersion, isNull);
    }
    expect(await dest.select(dest.outbox).get(), isEmpty);
  });
}
