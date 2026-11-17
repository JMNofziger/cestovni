'use strict';

const { randomUUID } = require('crypto');
const jwt = require('../../server/api/node_modules/jsonwebtoken');
const { assert, request, signUser } = require('./http');

function signAccess(claims, options = {}) {
  const { secret, issuer, audience, ...rest } = options;
  return jwt.sign(claims, secret, {
    algorithm: 'HS256',
    issuer,
    audience,
    expiresIn: 900,
    ...rest,
  });
}

async function main() {
  const secret = process.env.JWT_SECRET;
  const userA = process.env.USER_A;
  const issuer = process.env.AUTH_ISSUER_URL;
  const audience = process.env.AUTH_AUDIENCE || 'cestovni';
  assert(secret && userA && process.env.TOKEN_A && issuer, 'TOKEN_A, USER_A, JWT_SECRET, AUTH_ISSUER_URL required');
  const live = jwt.decode(process.env.TOKEN_A);

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

  const notUuid = signAccess(
    { sub: 'alice', sid: randomUUID() },
    { secret, issuer, audience }
  );
  const badSub = await request('GET', '/api/v1/restore/manifest', { token: notUuid });
  assert(badSub.status === 401, `non-uuid sub status ${badSub.status}`);
  assert(badSub.json.error.code === 'unauthenticated', 'non-uuid sub code');

  const ok = await request('GET', '/api/v1/restore/manifest', {
    token: process.env.TOKEN_A,
  });
  assert(ok.status === 200, `valid token status ${ok.status}`);
  assert(ok.json.tables.length === 5, 'manifest has 5 tables');

  const noSid = signAccess({ sub: userA }, { secret, issuer, audience });
  const missingSid = await request('GET', '/api/v1/restore/manifest', { token: noSid });
  assert(missingSid.status === 401, `missing sid status ${missingSid.status}`);
  assert(missingSid.json.error.code === 'unauthenticated', 'missing sid code');

  const unknownSid = signAccess(
    { sub: userA, sid: randomUUID() },
    { secret, issuer, audience }
  );
  const inactive = await request('GET', '/api/v1/restore/manifest', { token: unknownSid });
  assert(inactive.status === 401, `unknown sid status ${inactive.status}`);
  assert(inactive.json.error.code === 'unauthenticated', 'unknown sid code');

  const badIss = signAccess(
    { sub: live.sub, sid: live.sid },
    { secret, issuer: 'https://evil.example', audience }
  );
  const wrongIss = await request('GET', '/api/v1/restore/manifest', { token: badIss });
  assert(wrongIss.status === 401, `wrong iss status ${wrongIss.status}`);
  assert(wrongIss.json.error.code === 'unauthenticated', 'wrong iss code');

  const badAud = signAccess(
    { sub: live.sub, sid: live.sid },
    { secret, issuer, audience: 'not-cestovni' }
  );
  const wrongAud = await request('GET', '/api/v1/restore/manifest', { token: badAud });
  assert(wrongAud.status === 401, `wrong aud status ${wrongAud.status}`);
  assert(wrongAud.json.error.code === 'unauthenticated', 'wrong aud code');

  const fresh = await signUser('auth-revoke-' + randomUUID());
  const beforeLogout = await request('GET', '/api/v1/restore/manifest', { token: fresh.token });
  assert(beforeLogout.status === 200, `before logout status ${beforeLogout.status}`);
  const loggedOut = await request('POST', '/api/v1/auth/logout', {
    body: { refresh_token: fresh.refreshToken },
  });
  assert(loggedOut.status === 204, `logout status ${loggedOut.status}`);
  const afterLogout = await request('GET', '/api/v1/restore/manifest', { token: fresh.token });
  assert(afterLogout.status === 401, `after logout status ${afterLogout.status}`);
  assert(afterLogout.json.error.code === 'unauthenticated', 'after logout code');

  const health = await request('GET', '/healthz');
  assert(health.status === 200 && health.json.ok === true, 'healthz without a token');

  console.log('auth contract ok');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
