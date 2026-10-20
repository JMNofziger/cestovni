'use strict';

// Allowlisted tables and client-writable columns. Names that are not
// lowercase identifiers are quoted. user_id, row_version, updated_at, and
// mutation_id are server-owned and never taken from the payload.

const QUOTED = new Set(['volume_uL', 'tank_capacity_uL']);

const TABLES = {
  vehicles: {
    columns: [
      'name',
      'make',
      'model',
      'year',
      'vin',
      'fuel_type',
      'tank_capacity_uL',
      'archived_at',
      'deleted_at',
    ],
    requiredOnInsert: ['name', 'fuel_type'],
  },
  fill_ups: {
    columns: [
      'vehicle_id',
      'filled_at',
      'odometer_m',
      'volume_uL',
      'total_price_cents',
      'currency_code',
      'is_full',
      'missed_before',
      'odometer_reset',
      'notes',
      'deleted_at',
    ],
    requiredOnInsert: [
      'vehicle_id',
      'filled_at',
      'odometer_m',
      'volume_uL',
      'total_price_cents',
      'currency_code',
      'is_full',
    ],
  },
  maintenance_rules: {
    columns: [
      'vehicle_id',
      'name',
      'cadence_m',
      'cadence_days',
      'enabled',
      'notes',
      'deleted_at',
    ],
    requiredOnInsert: ['vehicle_id', 'name'],
  },
  maintenance_events: {
    columns: [
      'vehicle_id',
      'rule_id',
      'performed_at',
      'odometer_m',
      'cost_cents',
      'currency_code',
      'category',
      'shop',
      'notes',
      'deleted_at',
    ],
    requiredOnInsert: ['vehicle_id', 'performed_at', 'currency_code'],
  },
  settings: {
    columns: [
      'preferred_distance_unit',
      'preferred_volume_unit',
      'currency_code',
      'timezone',
      'default_vehicle_id',
      'deleted_at',
    ],
    requiredOnInsert: [
      'preferred_distance_unit',
      'preferred_volume_unit',
      'currency_code',
      'timezone',
    ],
  },
};

const TABLE_NAMES = Object.keys(TABLES);

function quoteIdent(name) {
  if (QUOTED.has(name)) return `"${name}"`;
  if (!/^[a-z_][a-z0-9_]*$/.test(name)) {
    throw new Error(`refusing identifier ${name}`);
  }
  return name;
}

module.exports = { TABLES, TABLE_NAMES, quoteIdent };
