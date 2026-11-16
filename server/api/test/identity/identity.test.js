'use strict';

const assert = require('node:assert/strict');
const crypto = require('crypto');
const { after, before, describe, test } = require('node:test');
const jwt = require('jsonwebtoken');
const { pool } = require('../../src/db');
const {
  GoogleTokenInvalidError,
  LoginCodeInvalidError,
  OAuthStateInvalidError,
  RefreshInvalidError,
  checkIdentityReady,
  consumeLoginCode,
  consumeOAuthState,
  createGoogleVerifier,
  createLoginCode,
  createOAuthState,
  findOrCreateUser,
  getUser,
  refreshSession,
  revokeSession,
  sessionIsActive,
  sha256,
  startSession,
} = require('../../src/identity');

const CLIENT_ID = 'test-google-client-id.apps.googleusercontent.com';
const NOW_MS = Date.parse('2026-06-01T12:00:00.000Z');
const NOW_SEC = Math.floor(NOW_MS / 1000);
const VERIFIER = `ces81-${'v'.repeat(43)}`;

const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
});
const jwk = publicKey.export({ format: 'jwk' });
jwk.kid = 'kid-1';
jwk.alg = 'RS256';
jwk.use = 'sig';

function b64url(value) {
  return Buffer.from(value).toString('base64url');
}

// jsonwebtoken's noTimestamp option deletes iat, so tests sign directly.
function signGoogle(claims, kid = 'kid-1') {
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT', kid }));
  const body = b64url(JSON.stringify({
    iss: 'https://accounts.google.com',
    aud: CLIENT_ID,
    sub: 'google-sub-valid',
    email: 'person@example.com',
    email_verified: true,
    nonce: 'nonce-1',
    iat: NOW_SEC,
    exp: NOW_SEC + 3600,
    ...claims,
  }));
  const data = `${header}.${body}`;
  const sig = crypto.sign('RSA-SHA256', Buffer.from(data), privateKey).toString('base64url');
  return `${data}.${sig}`;
}

function verifierReturning(keys) {
  return createGoogleVerifier({
    clientId: CLIENT_ID,
    now: () => NOW_MS,
    fetchJwks: async () => ({ keys }),
  });
}

before(() => {
  process.env.JWT_SECRET = 'ces81-test-secret-must-be-32-characters';
  process.env.AUTH_ISSUER_URL = 'http://127.0.0.1:8080';
  process.env.AUTH_AUDIENCE = 'cestovni';
  process.env.GOOGLE_CLIENT_ID = CLIENT_ID;
});

after(async () => {
  await pool.query("DELETE FROM auth_oauth_states WHERE code_verifier LIKE 'ces81-%'");
  await pool.query("DELETE FROM auth_login_transactions WHERE google_sub LIKE 'ces81-%'");
  await pool.query("DELETE FROM users WHERE google_sub LIKE 'ces81-%'");
  await pool.end();
});

describe('identity', { concurrency: 1 }, () => {
  test('verifier accepts a valid token and rejects each failed check', async () => {
    const cases = [
      {
        name: 'valid',
        token: signGoogle({}),
        nonce: 'nonce-1',
        ok: true,
      },
      {
        name: 'wrong aud',
        token: signGoogle({ aud: 'other-client' }),
        nonce: 'nonce-1',
      },
      {
        name: 'wrong iss',
        token: signGoogle({ iss: 'https://evil.example' }),
        nonce: 'nonce-1',
      },
      {
        name: 'expired',
        token: signGoogle({ iat: NOW_SEC - 180, exp: NOW_SEC - 120 }),
        nonce: 'nonce-1',
      },
      {
        name: 'iat older than 10 minutes',
        token: signGoogle({ iat: NOW_SEC - 661, exp: NOW_SEC + 3600 }),
        nonce: 'nonce-1',
      },
      {
        name: 'wrong nonce',
        token: signGoogle({ nonce: 'nonce-1' }),
        nonce: 'other-nonce',
      },
      {
        name: 'email_verified false',
        token: signGoogle({ email: 'person@example.com', email_verified: false }),
        nonce: 'nonce-1',
      },
    ];

    for (const item of cases) {
      const verify = verifierReturning([jwk]);
      if (item.ok) {
        const got = await verify(item.token, { nonce: item.nonce });
        assert.deepEqual(got, {
          googleSub: 'google-sub-valid',
          email: 'person@example.com',
        }, item.name);
      } else {
        await assert.rejects(
          () => verify(item.token, { nonce: item.nonce }),
          GoogleTokenInvalidError,
          item.name
        );
      }
    }

    let fetches = 0;
    const verifyUnknown = createGoogleVerifier({
      clientId: CLIENT_ID,
      now: () => NOW_MS,
      fetchJwks: async () => {
        fetches += 1;
        return { keys: [{ ...jwk, kid: 'kid-other' }] };
      },
    });
    const unknown = signGoogle({}, 'kid-missing');
    await assert.rejects(
      () => verifyUnknown(unknown, { nonce: 'nonce-1' }),
      GoogleTokenInvalidError
    );
    assert.equal(fetches, 1);
    await assert.rejects(
      () => verifyUnknown(unknown, { nonce: 'nonce-1' }),
      GoogleTokenInvalidError
    );
    assert.equal(fetches, 1);
  });

  test('findOrCreateUser keeps one id per google_sub and coalesces email', async () => {
    const subA = 'ces81-sub-a';
    const subB = 'ces81-sub-b';
    await pool.query('DELETE FROM users WHERE google_sub IN ($1, $2)', [subA, subB]);

    const first = await findOrCreateUser({ googleSub: subA, email: null });
    const again = await findOrCreateUser({ googleSub: subA, email: null });
    assert.equal(again.id, first.id);
    assert.equal(again.email, null);

    const other = await findOrCreateUser({ googleSub: subB, email: null });
    assert.notEqual(other.id, first.id);

    const updated = await findOrCreateUser({ googleSub: subA, email: 'a@example.com' });
    assert.equal(updated.id, first.id);
    assert.equal(updated.email, 'a@example.com');

    const kept = await findOrCreateUser({ googleSub: subA, email: null });
    assert.equal(kept.id, first.id);
    assert.equal(kept.email, 'a@example.com');

    const loaded = await getUser(first.id);
    assert.deepEqual(loaded, { id: first.id, email: 'a@example.com' });
    assert.equal(await getUser('33333333-3333-4333-8333-333333333333'), null);
  });

  test('sessionIsActive is false when revoked, unknown, or expired', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-session', email: null });
    const started = await startSession(user.id);
    assert.equal(await sessionIsActive({ sessionId: started.sessionId, userId: user.id }), true);
    assert.equal(
      await sessionIsActive({
        sessionId: '33333333-3333-4333-8333-333333333333',
        userId: user.id,
      }),
      false
    );

    await revokeSession(randomUnused());
    assert.equal(await sessionIsActive({ sessionId: started.sessionId, userId: user.id }), true);
    await revokeSession(started.refreshToken);
    assert.equal(await sessionIsActive({ sessionId: started.sessionId, userId: user.id }), false);
    await revokeSession(started.refreshToken);
    assert.equal(await sessionIsActive({ sessionId: started.sessionId, userId: user.id }), false);

    const expiring = await startSession(user.id);
    await pool.query(
      `UPDATE auth_sessions SET expires_at = now() - interval '1 second' WHERE id = $1`,
      [expiring.sessionId]
    );
    assert.equal(
      await sessionIsActive({ sessionId: expiring.sessionId, userId: user.id }),
      false
    );
  });

  test('refresh rotates and keeps the same sid', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-refresh-rotate', email: null });
    const started = await startSession(user.id);
    const next = await refreshSession(started.refreshToken);
    assert.notEqual(next.refreshToken, started.refreshToken);
    assert.equal(next.sessionId, started.sessionId);
    assert.equal(next.userId, user.id);
    const claims = jwt.decode(next.accessToken);
    assert.equal(claims.sub, user.id);
    assert.equal(claims.sid, started.sessionId);
    assert.equal(claims.iss, 'http://127.0.0.1:8080');
    assert.equal(claims.aud, 'cestovni');
    assert.equal(claims.exp - claims.iat, 900);
    assert.equal(claims.email, undefined);
  });

  test('refresh replay inside 30 seconds returns a new pair and stays active', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-refresh-grace', email: null });
    const started = await startSession(user.id);
    const first = await refreshSession(started.refreshToken);
    const second = await refreshSession(started.refreshToken);
    assert.notEqual(second.refreshToken, first.refreshToken);
    assert.notEqual(second.refreshToken, started.refreshToken);
    assert.equal(
      await sessionIsActive({ sessionId: started.sessionId, userId: user.id }),
      true
    );
    const row = await pool.query(
      'SELECT revoked_at FROM auth_sessions WHERE id = $1',
      [started.sessionId]
    );
    assert.equal(row.rows[0].revoked_at, null);
  });

  test('refresh replay after 31 seconds revokes the session', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-refresh-reuse', email: null });
    const started = await startSession(user.id);
    const successor = await refreshSession(started.refreshToken);
    await pool.query(
      `UPDATE auth_refresh_tokens
          SET used_at = now() - interval '31 seconds'
        WHERE token_hash = $1`,
      [sha256(started.refreshToken)]
    );
    await assert.rejects(() => refreshSession(started.refreshToken), RefreshInvalidError);
    const row = await pool.query(
      'SELECT revoked_reason FROM auth_sessions WHERE id = $1',
      [started.sessionId]
    );
    assert.equal(row.rows[0].revoked_reason, 'reuse_detected');
    assert.equal(
      await sessionIsActive({ sessionId: started.sessionId, userId: user.id }),
      false
    );
    await assert.rejects(() => refreshSession(successor.refreshToken), RefreshInvalidError);
  });

  test('unknown, expired, and revoked refresh tokens throw the same error', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-refresh-invalid', email: null });
    const expired = await startSession(user.id);
    await pool.query(
      `UPDATE auth_refresh_tokens
          SET expires_at = now() - interval '1 second'
        WHERE token_hash = $1`,
      [sha256(expired.refreshToken)]
    );
    const revoked = await startSession(user.id);
    await revokeSession(revoked.refreshToken);

    const caught = [];
    for (const run of [
      () => refreshSession(randomUnused()),
      () => refreshSession(expired.refreshToken),
      () => refreshSession(revoked.refreshToken),
    ]) {
      try {
        await run();
        caught.push(null);
      } catch (err) {
        caught.push(err);
      }
    }
    assert.equal(caught.length, 3);
    for (const err of caught) {
      assert.ok(err instanceof RefreshInvalidError);
      assert.equal(err.name, 'RefreshInvalidError');
      assert.equal(err.message, 'refresh_invalid');
    }
  });

  test('refresh token is stored as sha256 only', async () => {
    const user = await findOrCreateUser({ googleSub: 'ces81-storage', email: null });
    const started = await startSession(user.id);
    const row = await pool.query(
      `SELECT token_hash
         FROM auth_refresh_tokens
        WHERE session_id = $1`,
      [started.sessionId]
    );
    assert.equal(row.rowCount, 1);
    assert.equal(row.rows[0].token_hash.length, 32);
    assert.ok(row.rows[0].token_hash.equals(sha256(started.refreshToken)));
  });

  test('oauth state is single use, hashed, and expires', async () => {
    const state = await createOAuthState({
      client: 'android',
      nonce: 'nonce-state',
      codeVerifier: VERIFIER,
    });
    const hash = sha256(state);
    const stored = await pool.query(
      'SELECT state_hash, code_verifier FROM auth_oauth_states WHERE state_hash = $1',
      [hash]
    );
    assert.equal(stored.rowCount, 1);
    assert.equal(stored.rows[0].state_hash.length, 32);
    assert.equal(stored.rows[0].code_verifier, VERIFIER);

    const consumed = await consumeOAuthState(state);
    assert.deepEqual(consumed, {
      client: 'android',
      nonce: 'nonce-state',
      codeVerifier: VERIFIER,
    });
    await assert.rejects(() => consumeOAuthState(state), OAuthStateInvalidError);

    const stale = await createOAuthState({
      client: 'portal',
      nonce: 'nonce-stale',
      codeVerifier: VERIFIER,
    });
    await pool.query(
      `UPDATE auth_oauth_states
          SET expires_at = now() - interval '1 second'
        WHERE state_hash = $1`,
      [sha256(stale)]
    );
    await assert.rejects(() => consumeOAuthState(stale), OAuthStateInvalidError);
  });

  test('login code is single use, hashed, and expires', async () => {
    const code = await createLoginCode({
      googleSub: 'ces81-login',
      email: 'login@example.com',
    });
    const hash = sha256(code);
    const stored = await pool.query(
      'SELECT code_hash FROM auth_login_transactions WHERE code_hash = $1',
      [hash]
    );
    assert.equal(stored.rowCount, 1);
    assert.equal(stored.rows[0].code_hash.length, 32);

    const consumed = await consumeLoginCode(code);
    assert.deepEqual(consumed, {
      googleSub: 'ces81-login',
      email: 'login@example.com',
    });
    await assert.rejects(() => consumeLoginCode(code), LoginCodeInvalidError);

    const stale = await createLoginCode({ googleSub: 'ces81-login-stale', email: null });
    await pool.query(
      `UPDATE auth_login_transactions
          SET expires_at = now() - interval '1 second'
        WHERE code_hash = $1`,
      [sha256(stale)]
    );
    await assert.rejects(() => consumeLoginCode(stale), LoginCodeInvalidError);
  });

  test('checkIdentityReady resolves', async () => {
    await checkIdentityReady();
  });
});

function randomUnused() {
  return crypto.randomBytes(32).toString('base64url');
}
