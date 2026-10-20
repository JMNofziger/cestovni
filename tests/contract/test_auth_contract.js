'use strict';

const jwt = require('../../server/api/node_modules/jsonwebtoken');
const { assert, request } = require('./http');

async function main() {
  const secret = process.env.JWT_SECRET;
  const userA = process.env.USER_A;
  assert(secret && userA && process.env.TOKEN_A, 'TOKEN_A, USER_A, JWT_SECRET required');

  const missing = await request('GET', '/api/v1/restore/manifest');
  assert(missing.status === 401, `missing token status ${missing.status}`);
  assert(missing.json.error.code === 'unauthenticated', 'missing token code');
  assert(missing.json.error.retriable === false, 'missing token retriable');

  const empty = await request('GET', '/api/v1/restore/manifest', { token: '' });
  assert(empty.status === 401, `empty bearer status ${empty.status}`);

  const garbage = await request('GET', '/api/v1/changes?table=vehicles', {
    token: 'not-a-jwt',
  });
  assert(garbage.status === 401, `garbage token status ${garbage.status}`);
  assert(garbage.json.error.code === 'unauthenticated', 'garbage token code');

  const wrongKey = jwt.sign({ sub: userA }, 'other-secret', {
    algorithm: 'HS256',
    expiresIn: '1h',
  });
  const badSig = await request('GET', '/api/v1/restore/manifest', { token: wrongKey });
  assert(badSig.status === 401, `bad signature status ${badSig.status}`);

  const expired = jwt.sign(
    { sub: userA, exp: Math.floor(Date.now() / 1000) - 60 },
    secret,
    { algorithm: 'HS256' },
  );
  const expiredRes = await request('GET', '/api/v1/restore/manifest', { token: expired });
  assert(expiredRes.status === 401, `expired status ${expiredRes.status}`);
  assert(expiredRes.json.error.code === 'token_expired', `expired code ${expiredRes.json.error.code}`);

  const notUuid = jwt.sign({ sub: 'alice' }, secret, {
    algorithm: 'HS256',
    expiresIn: '1h',
  });
  const badSub = await request('GET', '/api/v1/restore/manifest', { token: notUuid });
  assert(badSub.status === 401, `non-uuid sub status ${badSub.status}`);

  const ok = await request('GET', '/api/v1/restore/manifest', {
    token: process.env.TOKEN_A,
  });
  assert(ok.status === 200, `valid token status ${ok.status}`);
  assert(ok.json.tables.length === 5, 'manifest has 5 tables');

  const health = await request('GET', '/healthz');
  assert(health.status === 200 && health.json.ok === true, 'healthz without a token');

  console.log('auth contract ok');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
