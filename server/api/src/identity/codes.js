'use strict';

const { withAuthRole } = require('./db');
const { LoginCodeInvalidError, OAuthStateInvalidError } = require('./errors');
const { randomToken, sha256 } = require('./tokens');

async function createOAuthState({ client, nonce, codeVerifier }) {
  const state = randomToken();
  await withAuthRole(async (db) => {
    await db.query(
      `INSERT INTO auth_oauth_states
         (state_hash, code_verifier, client, nonce, expires_at)
       VALUES ($1, $2, $3, $4, now() + interval '10 minutes')`,
      [sha256(state), codeVerifier, client, nonce]
    );
  });
  return state;
}

async function consumeOAuthState(state) {
  const hash = sha256(state);
  return withAuthRole(async (db) => {
    const result = await db.query(
      `DELETE FROM auth_oauth_states
        WHERE state_hash = $1
          AND expires_at > now()
        RETURNING client, nonce, code_verifier`,
      [hash]
    );
    if (result.rowCount !== 1) throw new OAuthStateInvalidError();
    const row = result.rows[0];
    return { client: row.client, nonce: row.nonce, codeVerifier: row.code_verifier };
  });
}

async function createLoginCode({ googleSub, email }) {
  const code = randomToken();
  await withAuthRole(async (db) => {
    await db.query(
      `INSERT INTO auth_login_transactions
         (code_hash, google_sub, email, expires_at)
       VALUES ($1, $2, $3, now() + interval '60 seconds')`,
      [sha256(code), googleSub, email ?? null]
    );
  });
  return code;
}

async function consumeLoginCode(code) {
  const hash = sha256(code);
  return withAuthRole(async (db) => {
    const result = await db.query(
      `UPDATE auth_login_transactions
          SET consumed_at = now()
        WHERE code_hash = $1
          AND consumed_at IS NULL
          AND expires_at > now()
        RETURNING google_sub, email`,
      [hash]
    );
    if (result.rowCount !== 1) throw new LoginCodeInvalidError();
    return { googleSub: result.rows[0].google_sub, email: result.rows[0].email };
  });
}

async function sweepExpired() {
  await withAuthRole(async (db) => {
    await db.query('DELETE FROM auth_oauth_states WHERE expires_at <= now()');
    await db.query('DELETE FROM auth_login_transactions WHERE expires_at <= now()');
  });
}

module.exports = {
  createOAuthState,
  consumeOAuthState,
  createLoginCode,
  consumeLoginCode,
  sweepExpired,
};
