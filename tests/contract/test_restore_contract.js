'use strict';

const { randomUUID } = require('crypto');
const { assert, request, signUser } = require('./http');

const NAMES = [
  'vehicles',
  'fill_ups',
  'maintenance_rules',
  'maintenance_events',
  'settings',
];

async function manifest(token) {
  const res = await request('GET', '/api/v1/restore/manifest', { token });
  assert(res.status === 200, `manifest ${res.status} ${res.text}`);
  return res.json;
}

async function main() {
  const userE = randomUUID();
  const userF = randomUUID();
  const tokenE = signUser(userE);
  const tokenF = signUser(userF);

  const before = await manifest(tokenE);
  assert(before.tables.length === 5, 'five tables');
  assert(
    before.tables.map((t) => t.table).join() === NAMES.join(),
    `table order ${before.tables.map((t) => t.table)}`,
  );
  for (const table of before.tables) {
    assert(table.row_count === 0, `${table.table} starts empty for a new user`);
    assert(table.max_row_version === 0, `${table.table} max_row_version`);
  }

  const vehicleId = randomUUID();
  const created = await request('POST', '/api/v1/mutations', {
    token: tokenE,
    body: {
      mutations: [
        {
          mutation_id: randomUUID(),
          table: 'vehicles',
          op: 'insert',
          row_id: vehicleId,
          payload: { name: 'Manifest car', fuel_type: 'lpg' },
        },
        {
          mutation_id: randomUUID(),
          table: 'settings',
          op: 'insert',
          row_id: userE,
          payload: {
            preferred_distance_unit: 'km',
            preferred_volume_unit: 'L',
            currency_code: 'EUR',
            timezone: 'Europe/Prague',
          },
        },
      ],
    },
  });
  assert(created.status === 200, created.text);
  assert(created.json.results.every((r) => r.status === 'applied'), JSON.stringify(created.json));

  const after = await manifest(tokenE);
  const vehicles = after.tables.find((t) => t.table === 'vehicles');
  const settings = after.tables.find((t) => t.table === 'settings');
  assert(vehicles.row_count === 1, `vehicles count ${vehicles.row_count}`);
  assert(
    vehicles.max_row_version === created.json.results[0].row_version,
    'vehicles max_row_version matches the insert',
  );
  assert(settings.row_count === 1, `settings count ${settings.row_count}`);
  assert(settings.max_row_version === created.json.results[1].row_version, 'settings version');

  const other = await manifest(tokenF);
  assert(
    other.tables.every((t) => t.row_count === 0),
    'user F manifest does not include user E rows',
  );
  const leaked = await request('GET', '/api/v1/changes?table=vehicles&since=0', {
    token: tokenF,
  });
  assert(
    !leaked.json.rows.some((row) => row.id === vehicleId),
    'user F changes hide user E vehicle',
  );

  console.log('restore contract ok');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
