'use strict';

const { randomUUID } = require('crypto');
const { assert, request, signUser } = require('./http');

async function mutate(token, mutations) {
  const res = await request('POST', '/api/v1/mutations', { token, body: { mutations } });
  assert(res.status === 200, `mutate status ${res.status} ${res.text}`);
  return res.json.results;
}

async function main() {
  const userC = randomUUID();
  const userD = randomUUID();
  const tokenC = signUser(userC);
  const tokenD = signUser(userD);

  const vehicles = [0, 1, 2].map((n) => {
    const rowId = randomUUID();
    return {
      rowId,
      mutation: {
        mutation_id: randomUUID(),
        table: 'vehicles',
        op: 'insert',
        row_id: rowId,
        payload: { name: `Car ${n}`, fuel_type: 'diesel' },
      },
    };
  });
  const inserted = await mutate(tokenC, vehicles.map((v) => v.mutation));
  assert(inserted.every((r) => r.status === 'applied'), JSON.stringify(inserted));
  const versions = inserted.map((r) => r.row_version);
  assert(versions[0] < versions[1] && versions[1] < versions[2], 'row_version increases');

  const page1 = await request('GET', '/api/v1/changes?table=vehicles&since=0&limit=2', {
    token: tokenC,
  });
  assert(page1.status === 200, `page1 ${page1.status}`);
  assert(page1.json.rows.length === 2, `page1 length ${page1.json.rows.length}`);
  assert(page1.json.has_more === true, 'page1 has_more');
  assert(page1.json.next_since === page1.json.rows[1].row_version, 'next_since is last row');
  assert(page1.json.rows[0].row_version < page1.json.rows[1].row_version, 'ascending');
  assert(page1.json.rows.every((row) => row.row_version > 0), 'since filter');

  const page2 = await request(
    `GET`,
    `/api/v1/changes?table=vehicles&since=${page1.json.next_since}&limit=2`,
    { token: tokenC },
  );
  assert(page2.json.rows.length === 1, `page2 length ${page2.json.rows.length}`);
  assert(page2.json.has_more === false, 'page2 has_more');
  assert(page2.json.rows[0].row_version > page1.json.next_since, 'page2 is after cursor');
  assert(page2.json.rows[0].id === vehicles[2].rowId, 'page2 is the third vehicle');

  const clamped = await request('GET', '/api/v1/changes?table=vehicles&since=0&limit=9999', {
    token: tokenC,
  });
  assert(clamped.headers.get('x-limit-clamped') === 'true', 'limit clamp header');
  assert(clamped.json.rows.length === 3, 'clamp does not drop rows under the cap');

  const fillId = randomUUID();
  const fill = await mutate(tokenC, [
    {
      mutation_id: randomUUID(),
      table: 'fill_ups',
      op: 'insert',
      row_id: fillId,
      payload: {
        vehicle_id: vehicles[0].rowId,
        filled_at: '2026-04-17T12:30:00.000Z',
        odometer_m: 12345000,
        volume_uL: 42100000,
        total_price_cents: 5912,
        currency_code: 'EUR',
        is_full: true,
      },
    },
    {
      mutation_id: randomUUID(),
      table: 'fill_ups',
      op: 'soft_delete',
      row_id: fillId,
    },
  ]);
  assert(fill[0].status === 'applied' && fill[1].status === 'applied', JSON.stringify(fill));

  const fills = await request('GET', '/api/v1/changes?table=fill_ups&since=0', {
    token: tokenC,
  });
  const tomb = fills.json.rows.find((row) => row.id === fillId);
  assert(tomb, 'soft-deleted fill-up is in the change stream');
  assert(tomb.deleted_at, 'deleted_at set');
  assert(tomb.volume_uL === 42100000, `volume_uL ${tomb.volume_uL}`);

  const other = await request('GET', '/api/v1/changes?table=vehicles&since=0', {
    token: tokenD,
  });
  assert(other.status === 200, `user D status ${other.status}`);
  assert(other.json.rows.length === 0, 'user D sees none of user C vehicles');

  console.log('changes contract ok');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
