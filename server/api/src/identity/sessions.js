'use strict';

const jwt = require('jsonwebtoken');
const { withAuthRole } = require('./db');
const { RefreshInvalidError } = require('./errors');
const { randomToken, sha256 } = require('./tokens');

function mintAccessToken({ userId, sessionId }) {
  return jwt.sign(
    { sub: userId, sid: sessionId },
    process.env.JWT_SECRET,
    {
      algorithm: 'HS256',
      issuer: process.env.AUTH_ISSUER_URL,
      audience: process.env.AUTH_AUDIENCE || 'cestovni',
      expiresIn: 900,
    }
  );
}

async function insertRefreshToken(client, sessionId, sessionExpiresAt) {
  const refreshToken = randomToken();
  await client.query(
    `INSERT INTO auth_refresh_tokens (session_id, token_hash, expires_at)
     VALUES ($1, $2, LEAST(now() + interval '60 days', $3::timestamptz))`,
    [sessionId, sha256(refreshToken), sessionExpiresAt]
  );
  return refreshToken;
}

async function startSession(userId) {
  return withAuthRole(async (client) => {
    const session = await client.query(
      `INSERT INTO auth_sessions (user_id, expires_at)
       VALUES ($1, now() + interval '180 days')
       RETURNING id, expires_at`,
      [userId]
    );
    const sessionId = session.rows[0].id;
    const sessionExpiresAt = session.rows[0].expires_at;
    const refreshToken = await insertRefreshToken(client, sessionId, sessionExpiresAt);
    return {
      sessionId,
      accessToken: mintAccessToken({ userId, sessionId }),
      refreshToken,
    };
  });
}

function pairFrom(row, refreshToken) {
  return {
    userId: row.user_id,
    sessionId: row.session_id,
    accessToken: mintAccessToken({ userId: row.user_id, sessionId: row.session_id }),
    refreshToken,
  };
}

async function refreshSession(refreshToken) {
  const hash = sha256(refreshToken);
  return withAuthRole(async (client) => {
    // Aliases: node-pg keeps one value per column name, so t.*, s.* would
    // hide the token expiry behind the session expiry.
    const found = await client.query(
      `SELECT t.id AS token_id,
              t.used_at,
              (t.expires_at <= now()) AS token_expired,
              (t.used_at IS NOT NULL AND now() - t.used_at <= interval '30 seconds') AS in_grace,
              s.id AS session_id,
              s.user_id,
              s.expires_at AS session_expires_at,
              s.revoked_at,
              (s.expires_at <= now()) AS session_expired
         FROM auth_refresh_tokens t
         JOIN auth_sessions s ON s.id = t.session_id
        WHERE t.token_hash = $1
        FOR UPDATE OF t`,
      [hash]
    );
    if (found.rowCount !== 1) throw new RefreshInvalidError();
    const row = found.rows[0];
    if (row.token_expired || row.revoked_at != null || row.session_expired) {
      throw new RefreshInvalidError();
    }

    if (row.used_at == null) {
      await client.query(
        'UPDATE auth_refresh_tokens SET used_at = now() WHERE id = $1',
        [row.token_id]
      );
      await client.query(
        'UPDATE auth_sessions SET last_used_at = now() WHERE id = $1',
        [row.session_id]
      );
      const next = await insertRefreshToken(client, row.session_id, row.session_expires_at);
      return pairFrom(row, next);
    }

    if (row.in_grace) {
      const next = await insertRefreshToken(client, row.session_id, row.session_expires_at);
      return pairFrom(row, next);
    }

    await client.query(
      `UPDATE auth_sessions
          SET revoked_at = now(), revoked_reason = 'reuse_detected'
        WHERE id = $1 AND revoked_at IS NULL`,
      [row.session_id]
    );
    // Commit before the throw. withAuthRole rolls back on error, which
    // would undo the revocation.
    await client.query('COMMIT');
    throw new RefreshInvalidError();
  });
}

async function revokeSession(refreshToken) {
  const hash = sha256(refreshToken);
  await withAuthRole(async (client) => {
    await client.query(
      `UPDATE auth_sessions s
          SET revoked_at = now(), revoked_reason = 'logout'
         FROM auth_refresh_tokens t
        WHERE t.token_hash = $1
          AND s.id = t.session_id
          AND s.revoked_at IS NULL`,
      [hash]
    );
  });
}

async function sessionIsActive({ sessionId, userId }) {
  return withAuthRole(async (client) => {
    const result = await client.query(
      `SELECT 1
         FROM auth_sessions
        WHERE id = $1
          AND user_id = $2
          AND revoked_at IS NULL
          AND expires_at > now()`,
      [sessionId, userId]
    );
    return result.rowCount === 1;
  });
}

module.exports = {
  mintAccessToken,
  startSession,
  refreshSession,
  revokeSession,
  sessionIsActive,
};
