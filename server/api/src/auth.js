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

function userIdFromRequest(req, secret) {
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
    payload = jwt.verify(token, secret, { algorithms: ['HS256'] });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw new AuthError('token_expired', 'token expired');
    }
    throw new AuthError('unauthenticated', 'invalid bearer token');
  }
  const sub = payload && payload.sub;
  if (typeof sub !== 'string' || !UUID_RE.test(sub)) {
    throw new AuthError('unauthenticated', 'token sub is not a user uuid');
  }
  return sub;
}

module.exports = { userIdFromRequest, AuthError, UUID_RE };
