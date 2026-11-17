'use strict';

const { randomUUID } = require('crypto');
const { assert, request, signUser } = require('./http');

function vehicle(rowId, mutationId, name) {
  return {
    mutation_id: mutationId,
    table: 'vehicles',
    op: 'insert',
    row_id: rowId,
    payload: { name, fuel_type: 'gasoline' },
  };
}

async function main() {
  const tokenB = process.env.TOKEN_B;
  assert(tokenB, 'TOKEN_B required');

  const fresh = await signUser(`account-a-${randomUUID()}`);

  const empty = await request('DELETE', '/api/v1/account', {
    token: fresh.token,
    rawBody: '',
  });
  assert(empty.status === 400, `empty body status ${empty.status} ${empty.text}`);
  assert(empty.json && empty.json.error.code === 'bad_request', 'empty body is bad_request');

  const denied = await request('DELETE', '/api/v1/account', {
    token: fresh.token,
    body: { confirm: false },
  });
  assert(denied.status === 400, `confirm false status ${denied.status} ${denied.text}`);
  assert(denied.json && denied.json.error.code === 'bad_request', 'confirm false is bad_request');

  const still = await request('GET', '/api/v1/restore/manifest', { token: fresh.token });
  assert(still.status === 200, `manifest after refused delete ${still.status} ${still.text}`);

  const bRow = randomUUID();
  const bInsert = await request('POST', '/api/v1/mutations', {
    token: tokenB,
    body: { mutations: [vehicle(bRow, randomUUID(), 'Keep B')] },
  });
  assert(bInsert.status === 200, `B insert ${bInsert.status} ${bInsert.text}`);
  assert(bInsert.json.results[0].status === 'applied', 'B vehicle applied');

  const aRow = randomUUID();
  const aInsert = await request('POST', '/api/v1/mutations', {
    token: fresh.token,
    body: { mutations: [vehicle(aRow, randomUUID(), 'Delete A')] },
  });
  assert(aInsert.status === 200, `A insert ${aInsert.status} ${aInsert.text}`);
  assert(aInsert.json.results[0].status === 'applied', 'A vehicle applied');

  const deleted = await request('DELETE', '/api/v1/account', {
    token: fresh.token,
    body: { confirm: true },
  });
  assert(deleted.status === 204, `delete status ${deleted.status} ${deleted.text}`);
  assert(deleted.text === '', '204 has no body');

  const gone = await request('GET', '/api/v1/restore/manifest', { token: fresh.token });
  assert(gone.status === 401, `manifest after delete ${gone.status} ${gone.text}`);

  const refresh = await request('POST', '/api/v1/auth/refresh', {
    body: { refresh_token: fresh.refreshToken },
  });
  assert(refresh.status === 401, `refresh after delete ${refresh.status} ${refresh.text}`);
  assert(
    refresh.json && refresh.json.error.code === 'refresh_invalid',
    `refresh code ${refresh.text}`,
  );

  const seenByB = await request('GET', '/api/v1/changes?table=vehicles&since=0&limit=500', {
    token: tokenB,
  });
  assert(seenByB.status === 200, `B changes ${seenByB.status} ${seenByB.text}`);
  assert(
    seenByB.json.rows.some((row) => row.id === bRow),
    'bootstrap user B still reads its vehicle',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
