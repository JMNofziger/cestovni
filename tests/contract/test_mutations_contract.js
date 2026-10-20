'use strict';

const { randomUUID } = require('crypto');
const { assert, request } = require('./http');

function vehicle(rowId, mutationId, payload) {
  return {
    mutation_id: mutationId,
    table: 'vehicles',
    op: 'insert',
    row_id: rowId,
    payload: { name: 'Car A', fuel_type: 'gasoline', ...payload },
  };
}

async function main() {
  const tokenA = process.env.TOKEN_A;
  const tokenB = process.env.TOKEN_B;
  const userB = process.env.USER_B;
  assert(tokenA && tokenB && userB, 'TOKEN_A, TOKEN_B, USER_B required');

  const rowId = randomUUID();
  const mutationId = randomUUID();
  const inserted = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    body: {
      mutations: [
        vehicle(rowId, mutationId, { user_id: userB, name: 'Owned by A' }),
      ],
    },
  });
  assert(inserted.status === 200, `insert status ${inserted.status} ${inserted.text}`);
  const applied = inserted.json.results[0];
  assert(applied.status === 'applied', `expected applied, got ${applied.status} ${JSON.stringify(applied)}`);
  assert(typeof applied.row_version === 'number' && applied.row_version > 0, 'row_version assigned');
  assert(typeof applied.server_updated_at === 'string', 'server_updated_at');
  assert(applied.row_id === rowId, 'row_id echoed');

  const retry = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    body: { mutations: [vehicle(rowId, mutationId)] },
  });
  const dup = retry.json.results[0];
  assert(dup.status === 'duplicate', `expected duplicate, got ${dup.status}`);
  assert(dup.row_version === applied.row_version, 'duplicate keeps row_version');

  const seenByA = await request(
    'GET',
    `/api/v1/changes?table=vehicles&since=0&limit=500`,
    { token: tokenA },
  );
  const mine = seenByA.json.rows.filter((row) => row.id === rowId);
  assert(mine.length === 1, `user A should see one row, got ${mine.length}`);
  assert(mine[0].user_id === process.env.USER_A, 'server assigned user_id from the token');
  assert(mine[0].name === 'Owned by A', 'name stored');

  const seenByB = await request('GET', '/api/v1/changes?table=vehicles&since=0&limit=500', {
    token: tokenB,
  });
  assert(
    !seenByB.json.rows.some((row) => row.id === rowId),
    'user B must not see user A row (client-sent user_id ignored)',
  );

  const mixed = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    body: {
      mutations: [
        vehicle(randomUUID(), randomUUID(), { name: 'Second' }),
        {
          mutation_id: randomUUID(),
          table: 'not_a_table',
          op: 'insert',
          row_id: randomUUID(),
          payload: {},
        },
        vehicle(randomUUID(), randomUUID(), { fuel_type: 'hydrogen' }),
      ],
    },
  });
  assert(mixed.status === 200, `mixed batch status ${mixed.status}`);
  assert(mixed.json.results[0].status === 'applied', 'good mutation applied');
  assert(mixed.json.results[1].status === 'rejected', 'unknown table rejected');
  assert(mixed.json.results[1].error.code === 'unknown_table', mixed.json.results[1].error.code);
  assert(mixed.json.results[1].error.retriable === false, 'unknown table not retriable');
  assert(mixed.json.results[2].status === 'rejected', 'bad fuel_type rejected');
  const stillThere = await request(
    'GET',
    `/api/v1/changes?table=vehicles&since=${mixed.json.results[0].row_version - 1}&limit=10`,
    { token: tokenA },
  );
  assert(
    stillThere.json.rows.some((row) => row.id === mixed.json.results[0].row_id),
    'partial rejection kept the applied row',
  );

  const tooMany = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    body: {
      mutations: Array.from({ length: 101 }, () => vehicle(randomUUID(), randomUUID())),
    },
  });
  assert(tooMany.status === 413, `batch cap status ${tooMany.status}`);
  assert(tooMany.json.error.code === 'batch_too_large', tooMany.json.error.code);

  const missing = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    body: {},
  });
  assert(missing.status === 400, `missing mutations status ${missing.status}`);

  const badJson = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    rawBody: '{',
  });
  assert(badJson.status === 400, `bad json status ${badJson.status}`);

  const huge = await request('POST', '/api/v1/mutations', {
    token: tokenA,
    rawBody: `{"mutations":[]}${'x'.repeat(1024 * 1024)}`,
  });
  assert(huge.status === 413, `oversize body status ${huge.status} ${huge.text}`);
  assert(huge.json && huge.json.error.code === 'payload_too_large', 'oversize code');

  console.log(`mutations contract ok row_version=${applied.row_version}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
