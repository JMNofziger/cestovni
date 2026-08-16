import 'package:cestovni/export/headers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locked to `docs/specs/export-v1.md` § A1. If this fails, the spec
/// and the assembler drifted — do not "fix" the test by re-deriving.
void main() {
  test('vehicles.csv header matches export-v1 § A1', () {
    expect(
      vehiclesCsvHeader,
      'id,user_key_hash,name,make,model,year,vin,fuel_type,tank_capacity_uL,tank_capacity_L,archived_at_utc,row_version,updated_at_utc',
    );
  });

  test('fill_ups.csv header matches export-v1 § A1', () {
    expect(
      fillUpsCsvHeader,
      'id,user_key_hash,vehicle_id,filled_at_utc,filled_at_local,odometer_m,odometer_km,odometer_mi,volume_uL,volume_L,volume_gal,total_price_cents,total_price_major,currency_code,is_full,missed_before,odometer_reset,notes,row_version,updated_at_utc',
    );
  });

  test('maintenance_rules.csv header includes notes', () {
    expect(
      maintenanceRulesCsvHeader,
      'id,user_key_hash,vehicle_id,name,cadence_km,cadence_days,enabled,notes,row_version,updated_at_utc',
    );
  });

  test('maintenance_events.csv header includes category and shop', () {
    expect(
      maintenanceEventsCsvHeader,
      'id,user_key_hash,vehicle_id,rule_id,performed_at_utc,performed_at_local,odometer_m,odometer_km,odometer_mi,cost_cents,cost_major,currency_code,category,shop,notes,row_version,updated_at_utc',
    );
  });

  test('settings.csv header includes default_vehicle_id', () {
    expect(
      settingsCsvHeader,
      'user_key_hash,preferred_distance_unit,preferred_volume_unit,currency_code,timezone,default_vehicle_id,row_version,updated_at_utc',
    );
  });

  test('ZIP entry names are the spec file set in order', () {
    expect(exportZipEntryNames, [
      'manifest.json',
      'README_export.txt',
      'vehicles.csv',
      'fill_ups.csv',
      'maintenance_rules.csv',
      'maintenance_events.csv',
      'settings.csv',
    ]);
  });
}
