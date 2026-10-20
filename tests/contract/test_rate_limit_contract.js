'use strict';

const { randomUUID } = require('crypto');
const { assert, request, signUser } = require('./http');

async function main() {
  const mutationLimit = Number(process.env.RATE_LIMIT_MUTATIONS_PER_MIN || 60);
  const changesLimit = Number(process.env.RATE_LIMIT_CHANGES_PER_MIN || 120);
  assert(
    Number.isInteger(mutationLimit) && mutationLimit >= 1 && mutationLimit <= 99,
    'RATE_LIMIT_MUTATIONS_PER_MIN must be 1..99 so the burst fits under the 100-mutation cap',
  );
  assert(
    Number.isInteger(changesLimit) && changesLimit >= 1,
    'RATE_LIMIT_CHANGES_PER_MIN must be a positive integer',
  );
  const token = signUser(randomUUID());

  const burst = await request('POST', '/api/v1/mutations', {
    token,
    body: {
      mutations: Array.from({ length: mutationLimit + 1 }, () => ({
        mutation_id: randomUUID(),
        table: 'vehicles',
        op: 'insert',
        row_id: randomUUID(),
        payload: { name: 'Burst', fuel_type: 'gasoline' },
      })),
    },
  });
  assert(burst.status === 429, `mutation burst status ${burst.status} ${burst.text}`);
  assert(burst.json.error.code === 'rate_limited', burst.json.error && burst.json.error.code);
  assert(burst.json.error.retriable === true, '429 is retriable');
  const retryAfter = Number(burst.headers.get('retry-after'));
  assert(Number.isInteger(retryAfter) && retryAfter >= 1, `Retry-After ${burst.headers.get('retry-after')}`);

  const untouched = await request('GET', '/api/v1/changes?table=vehicles&since=0', { token });
  assert(untouched.status === 200, `post-429 changes ${untouched.status}`);
  assert(untouched.json.rows.length === 0, 'denied burst did not write rows');

  const one = await request('POST', '/api/v1/mutations', {
    token,
    body: {
      mutations: [
        {
          mutation_id: randomUUID(),
          table: 'vehicles',
          op: 'insert',
          row_id: randomUUID(),
          payload: { name: 'After burst', fuel_type: 'gasoline' },
        },
      ],
    },
  });
  assert(one.status === 200 && one.json.results[0].status === 'applied', JSON.stringify(one.json));

  const reader = signUser(randomUUID());
  let limited = null;
  for (let i = 0; i < changesLimit + 1; i += 1) {
    const res = await request('GET', '/api/v1/restore/manifest', { token: reader });
    if (res.status === 429) {
      limited = res;
      assert(i === changesLimit, `429 arrived on request ${i}, expected ${changesLimit}`);
      break;
    }
    assert(res.status === 200, `manifest ${i} status ${res.status}`);
  }
  assert(limited, 'changes/manifest burst never returned 429');
  assert(Number(limited.headers.get('retry-after')) >= 1, 'changes Retry-After');

  console.log(`rate limit contract ok mutations>${mutationLimit} changes>${changesLimit}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
