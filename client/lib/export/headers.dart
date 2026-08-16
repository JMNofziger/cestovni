/// Authoritative CSV headers for CES-41.
///
/// Spec: `docs/specs/export-v1.md` § A1 (2026-08-16). Do not re-derive
/// from the 2026-04 body of that spec — these strings are the contract.
library;

const String vehiclesCsvHeader =
    'id,user_key_hash,name,make,model,year,vin,fuel_type,tank_capacity_uL,tank_capacity_L,archived_at_utc,row_version,updated_at_utc';

const String fillUpsCsvHeader =
    'id,user_key_hash,vehicle_id,filled_at_utc,filled_at_local,odometer_m,odometer_km,odometer_mi,volume_uL,volume_L,volume_gal,total_price_cents,total_price_major,currency_code,is_full,missed_before,odometer_reset,notes,row_version,updated_at_utc';

const String maintenanceRulesCsvHeader =
    'id,user_key_hash,vehicle_id,name,cadence_km,cadence_days,enabled,notes,row_version,updated_at_utc';

const String maintenanceEventsCsvHeader =
    'id,user_key_hash,vehicle_id,rule_id,performed_at_utc,performed_at_local,odometer_m,odometer_km,odometer_mi,cost_cents,cost_major,currency_code,category,shop,notes,row_version,updated_at_utc';

const String settingsCsvHeader =
    'user_key_hash,preferred_distance_unit,preferred_volume_unit,currency_code,timezone,default_vehicle_id,row_version,updated_at_utc';

/// ZIP entry names in spec order. The assembler writes exactly this set.
const List<String> exportZipEntryNames = [
  'manifest.json',
  'README_export.txt',
  'vehicles.csv',
  'fill_ups.csv',
  'maintenance_rules.csv',
  'maintenance_events.csv',
  'settings.csv',
];
