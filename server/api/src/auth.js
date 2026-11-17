'use strict';

const jwt = require('jsonwebtoken');

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class AuthError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    this.status = 401;
    this.retriable = false;
  }
}

async function userIdFromRequest(req, { secret, issuer, audience, sessionIsActive }) {
  const header = req.headers.authorization || '';
  if (!header.toLowerCase().startsWith('bearer ')) {
    throw new AuthError('unauthenticated', 'missing bearer token');
  }
  const token = header.slice(7).trim();
  if (!token) {
    throw new AuthError('unauthenticated', 'missing bearer token');
  }
  let payload;
  try {
    payload = jwt.verify(token, secret, {
      algorithms: ['HS256'],
      issuer,
      audience,
    });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw new AuthError('token_expired', 'token expired');
    }
    throw new AuthError('unauthenticated', 'invalid bearer token');
  }
  const sub = payload && payload.sub;
  const sid = payload && payload.sid;
  if (typeof sub !== 'string' || !UUID_RE.test(sub)) {
    throw new AuthError('unauthenticated', 'token sub is not a user uuid');
  }
  if (typeof sid !== 'string' || !UUID_RE.test(sid)) {
    throw new AuthError('unauthenticated', 'token sid is not a session uuid');
  }
  // Own connection. Do not call this while a withUser client is checked out.
  const active = await sessionIsActive({ sessionId: sid, userId: sub });
  if (!active) {
    throw new AuthError('unauthenticated', 'session is not active');
  }
  return sub;
}

module.exports = { userIdFromRequest, AuthError, UUID_RE };
