'use strict';

const crypto = require('crypto');
const path = require('path');
const jwt = require(path.join(__dirname, '../../server/api/node_modules/jsonwebtoken'));
const { assert } = require('./http');
const { fakeCode, fakeIdToken } = require('./fake-google');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SESSION_KEYS = [
  'access_token',
  'email',
  'expires_in',
  'refresh_expires_in',
  'refresh_token',
  'token_type',
  'user_id',
];
const SUB_A = 'ces83-sub-a';
const SUB_B = 'ces83-sub-b';
const EMAIL_A = 'a@example.com';

const bucket = crypto.randomInt(1, 250);
let ipSeq = 10;

function nextIp() {
  ipSeq += 1;
  return `10.${bucket}.${ipSeq}.4`;
}

async function request(method, urlPath, { token, body, rawBody, ip } = {}) {
  const headers = { 'X-Forwarded-For': ip || nextIp() };
  if (token != null) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (rawBody !== undefined) {
    payload = rawBody;
    headers['Content-Type'] = 'application/json';
  } else if (body !== undefined) {
    payload = JSON.stringify(body);
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(new URL(urlPath, process.env.API_BASE_URL), {
    method,
    headers,
    body: payload,
    redirect: 'manual',
  });
  const text = await res.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch (_) {
      json = null;
    }
  }
  return { status: res.status, headers: res.headers, json, text };
}

function locationOf(res) {
  const raw = res.headers.get('location');
  assert(raw, 'missing location');
  return new URL(raw);
}

function assertSession(json) {
  assert(json && typeof json === 'object', 'session body');
  assert(Object.keys(json).sort().join() === SESSION_KEYS.join(), 'session fields');
  assert(UUID_RE.test(json.user_id), 'user_id is a uuid');
  assert(json.token_type === 'Bearer', 'token_type');
  assert(json.expires_in === 900, 'expires_in');
  assert(json.refresh_expires_in === 5184000, 'refresh_expires_in');
  assert(typeof json.access_token === 'string' && json.access_token.length > 0, 'access_token');
  assert(typeof json.refresh_token === 'string' && json.refresh_token.length > 0, 'refresh_token');
}

async function main() {
  assert(process.env.API_BASE_URL, 'API_BASE_URL required');

  // 1. Valid fake ID token returns the session body.
  const first = await request('POST', '/api/v1/auth/google', {
    body: { id_token: fakeIdToken({ sub: SUB_A, email: EMAIL_A, emailVerified: true }) },
  });
  assert(first.status === 200, `sign-in status ${first.status}`);
  assert(first.headers.get('cache-control') === 'no-store', 'session cache-control');
  assertSession(first.json);
  assert(first.json.email === EMAIL_A, 'session email');
  const userA = first.json.user_id;
  const accessA = first.json.access_token;

  // 2. Same sub keeps the id. A different sub allocates a new one.
  const again = await request('POST', '/api/v1/auth/google', {
    body: { id_token: fakeIdToken({ sub: SUB_A, email: EMAIL_A, emailVerified: true }) },
  });
  assert(again.status === 200, `repeat sign-in status ${again.status}`);
  assert(again.json.user_id === userA, 'same sub returns the same user_id');
  const other = await request('POST', '/api/v1/auth/google', {
    body: { id_token: fakeIdToken({ sub: SUB_B, email: 'b@example.com', emailVerified: true }) },
  });
  assert(other.status === 200, `second sub status ${other.status}`);
  assert(other.json.user_id !== userA, 'different sub allocates a user_id');

  // 3. Bad signature and email_verified false.
  const badSig = jwt.sign(
    { sub: SUB_A, email: EMAIL_A, email_verified: true },
    'wrong-secret',
    { algorithm: 'HS256' }
  );
  const bad = await request('POST', '/api/v1/auth/google', { body: { id_token: badSig } });
  assert(bad.status === 401, `bad signature status ${bad.status}`);
  assert(bad.json.error.code === 'google_token_invalid', 'bad signature code');
  const unverified = await request('POST', '/api/v1/auth/google', {
    body: {
      id_token: fakeIdToken({ sub: SUB_A, email: EMAIL_A, emailVerified: false }),
    },
  });
  assert(unverified.status === 401, `email_verified status ${unverified.status}`);
  assert(unverified.json.error.code === 'google_token_invalid', 'email_verified code');

  // 4. Browser flow: start, callback, exchange.
  const started = await request('GET', '/api/v1/auth/google/start?client=android');
  assert(started.status === 302, `start status ${started.status}`);
  assert(started.headers.get('cache-control') === 'no-store', 'start cache-control');
  const google = locationOf(started);
  assert(google.hostname === 'accounts.google.com', 'google host');
  assert(google.pathname === '/o/oauth2/v2/auth', 'google path');
  const state = google.searchParams.get('state');
  const nonce = google.searchParams.get('nonce');
  assert(state, 'state');
  assert(nonce, 'nonce');
  assert(google.searchParams.get('code_challenge'), 'code_challenge');
  assert(google.searchParams.get('prompt') === 'select_account', 'prompt');
  assert(google.searchParams.get('response_type') === 'code', 'response_type');
  assert(google.searchParams.get('scope') === 'openid email', 'scope');
  assert(google.searchParams.get('code_challenge_method') === 'S256', 'code_challenge_method');
  if (process.env.AUTH_ISSUER_URL) {
    assert(
      google.searchParams.get('redirect_uri') === `${process.env.AUTH_ISSUER_URL}/api/v1/auth/google/callback`,
      'redirect_uri'
    );
  }
  if (process.env.GOOGLE_CLIENT_ID) {
    assert(google.searchParams.get('client_id') === process.env.GOOGLE_CLIENT_ID, 'client_id');
  }

  const callback = await request(
    'GET',
    `/api/v1/auth/google/callback?state=${encodeURIComponent(state)}&code=${encodeURIComponent(fakeCode({ sub: SUB_A, email: EMAIL_A, nonce }))}`
  );
  assert(callback.status === 302, `callback status ${callback.status}`);
  const appUrl = locationOf(callback);
  assert(appUrl.protocol === 'cestovni:', 'callback scheme');
  assert(appUrl.hostname === 'auth', 'callback host');
  assert(appUrl.pathname === '/callback', 'callback path');
  const loginCode = appUrl.searchParams.get('code');
  assert(loginCode, 'login code');
  assert(appUrl.searchParams.get('error') == null, 'callback has no error');

  const exchanged = await request('POST', '/api/v1/auth/google/exchange', {
    body: { code: loginCode },
  });
  assert(exchanged.status === 200, `exchange status ${exchanged.status}`);
  assertSession(exchanged.json);
  assert(exchanged.json.user_id === userA, 'exchange user matches the same sub');

  // 5. Login code and OAuth state are single use.
  const reusedCode = await request('POST', '/api/v1/auth/google/exchange', {
    body: { code: loginCode },
  });
  assert(reusedCode.status === 400, `reused code status ${reusedCode.status}`);
  assert(reusedCode.json.error.code === 'login_code_invalid', 'reused code');
  const reusedState = await request(
    'GET',
    `/api/v1/auth/google/callback?state=${encodeURIComponent(state)}&code=${encodeURIComponent(fakeCode({ sub: SUB_A, email: EMAIL_A, nonce }))}`
  );
  assert(reusedState.status === 400, `reused state status ${reusedState.status}`);
  assert(reusedState.json.error.code === 'oauth_state_invalid', 'reused state');
  assert(reusedState.headers.get('location') == null, 'bad state does not redirect');

  // 6. Google error redirects access_denied. A wrong nonce redirects google_token_invalid.
  const deniedStart = await request('GET', '/api/v1/auth/google/start?client=android');
  const deniedState = locationOf(deniedStart).searchParams.get('state');
  const denied = await request(
    'GET',
    `/api/v1/auth/google/callback?state=${encodeURIComponent(deniedState)}&error=access_denied`
  );
  assert(denied.status === 302, `access_denied status ${denied.status}`);
  const deniedUrl = locationOf(denied);
  assert(deniedUrl.searchParams.get('error') === 'access_denied', 'access_denied');
  assert(deniedUrl.searchParams.get('code') == null, 'access_denied has no code');

  const nonceStart = await request('GET', '/api/v1/auth/google/start?client=android');
  const nonceState = locationOf(nonceStart).searchParams.get('state');
  const wrongNonce = await request(
    'GET',
    `/api/v1/auth/google/callback?state=${encodeURIComponent(nonceState)}&code=${encodeURIComponent(fakeCode({ sub: SUB_A, email: EMAIL_A, nonce: 'wrong-nonce' }))}`
  );
  assert(wrongNonce.status === 302, `wrong nonce status ${wrongNonce.status}`);
  const wrongUrl = locationOf(wrongNonce);
  assert(wrongUrl.searchParams.get('error') === 'google_token_invalid', 'wrong nonce');
  assert(wrongUrl.searchParams.get('code') == null, 'wrong nonce has no code');

  // 7. client must be android or portal.
  const evil = await request('GET', '/api/v1/auth/google/start?client=evil');
  assert(evil.status === 400, `evil client status ${evil.status}`);
  assert(evil.json.error.code === 'bad_request', 'evil client code');
  const missingClient = await request('GET', '/api/v1/auth/google/start');
  assert(missingClient.status === 400, `missing client status ${missingClient.status}`);
  assert(missingClient.json.error.code === 'bad_request', 'missing client code');

  // 8. Refresh rotates. The previous token still works inside the grace window.
  const refreshSignIn = await request('POST', '/api/v1/auth/google', {
    body: { id_token: fakeIdToken({ sub: 'ces83-sub-refresh', email: EMAIL_A, emailVerified: true }) },
  });
  assert(refreshSignIn.status === 200, `refresh sign-in status ${refreshSignIn.status}`);
  const rotated = await request('POST', '/api/v1/auth/refresh', {
    body: { refresh_token: refreshSignIn.json.refresh_token },
  });
  assert(rotated.status === 200, `refresh status ${rotated.status}`);
  assertSession(rotated.json);
  assert(rotated.json.refresh_token !== refreshSignIn.json.refresh_token, 'refresh token rotated');
  // Two mints in the same second are the same JWT: iat has one-second resolution.
  const minted = jwt.decode(rotated.json.access_token);
  assert(minted && minted.sub === refreshSignIn.json.user_id, 'refreshed access token sub');
  assert(minted.exp - minted.iat === 900, 'refreshed access token lifetime');
  assert(rotated.json.user_id === refreshSignIn.json.user_id, 'refresh keeps user_id');
  const grace = await request('POST', '/api/v1/auth/refresh', {
    body: { refresh_token: refreshSignIn.json.refresh_token },
  });
  assert(grace.status === 200, `grace refresh status ${grace.status}`);
  assert(grace.json.refresh_token !== rotated.json.refresh_token, 'grace issues another token');

  // 9. Logout is 204, including for an unknown token. The revoked token cannot refresh.
  const logoutSignIn = await request('POST', '/api/v1/auth/google', {
    body: { id_token: fakeIdToken({ sub: 'ces83-sub-logout', email: null, emailVerified: true }) },
  });
  assert(logoutSignIn.status === 200, `logout sign-in status ${logoutSignIn.status}`);
  assert(logoutSignIn.json.email === null, 'null email');
  const loggedOut = await request('POST', '/api/v1/auth/logout', {
    body: { refresh_token: logoutSignIn.json.refresh_token },
  });
  assert(loggedOut.status === 204, `logout status ${loggedOut.status}`);
  assert(loggedOut.headers.get('cache-control') === 'no-store', 'logout cache-control');
  const afterLogout = await request('POST', '/api/v1/auth/refresh', {
    body: { refresh_token: logoutSignIn.json.refresh_token },
  });
  assert(afterLogout.status === 401, `revoked refresh status ${afterLogout.status}`);
  assert(afterLogout.json.error.code === 'refresh_invalid', 'revoked refresh code');
  const unknownLogout = await request('POST', '/api/v1/auth/logout', {
    body: { refresh_token: crypto.randomBytes(32).toString('base64url') },
  });
  assert(unknownLogout.status === 204, `unknown logout status ${unknownLogout.status}`);

  // 10. The access token from case 1 is accepted by a sync route.
  const manifest = await request('GET', '/api/v1/restore/manifest', { token: accessA });
  assert(manifest.status === 200, `manifest status ${manifest.status}`);
  assert(Array.isArray(manifest.json.tables), 'manifest tables');

  // 11. Auth bodies are capped at 1 KiB. Non-JSON is 400.
  const oversized = await request('POST', '/api/v1/auth/refresh', {
    rawBody: `{"refresh_token":"${'x'.repeat(1100)}"}`,
  });
  assert(oversized.status === 413, `oversized status ${oversized.status}`);
  assert(oversized.json.error.code === 'payload_too_large', 'oversized code');
  const notJson = await request('POST', '/api/v1/auth/refresh', { rawBody: 'not-json' });
  assert(notJson.status === 400, `non-json status ${notJson.status}`);
  assert(notJson.json.error.code === 'bad_request', 'non-json code');

  // 12. Sign-in limit is 20 per IP. A different forwarded IP is not limited.
  const limitedIp = nextIp();
  const openIp = nextIp();
  for (let i = 0; i < 20; i += 1) {
    const res = await request('POST', '/api/v1/auth/google/exchange', {
      ip: limitedIp,
      body: { code: 'not-a-login-code' },
    });
    assert(res.status === 400, `limited exchange ${i} status ${res.status}`);
  }
  const blocked = await request('POST', '/api/v1/auth/google/exchange', {
    ip: limitedIp,
    body: { code: 'not-a-login-code' },
  });
  assert(blocked.status === 429, `rate limit status ${blocked.status}`);
  assert(blocked.json.error.code === 'rate_limited', 'rate limit code');
  assert(blocked.json.error.retriable === true, 'rate limit retriable');
  const retryAfter = Number(blocked.headers.get('retry-after'));
  assert(Number.isInteger(retryAfter) && retryAfter >= 1, 'Retry-After');
  const otherIp = await request('POST', '/api/v1/auth/google/exchange', {
    ip: openIp,
    body: { code: 'not-a-login-code' },
  });
  assert(otherIp.status === 400, `other ip status ${otherIp.status}`);

  console.log('identity contract ok');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
