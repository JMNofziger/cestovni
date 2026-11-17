'use strict';

// Contract-test entry. Not a deploy target. CI starts this file instead of src/server.js.
// FAKE_GOOGLE_SECRET must match the constant in tests/contract/fake-google.js.

const FAKE_GOOGLE_SECRET = 'ces83-contract-fake-google-secret';

function fail(message) {
  console.error(message);
  process.exit(1);
}

const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) fail('JWT_SECRET is required');
if (jwtSecret.length < 32) fail('JWT_SECRET must be at least 32 characters');
if (!process.env.AUTH_ISSUER_URL) fail('AUTH_ISSUER_URL is required');
if (!process.env.GOOGLE_CLIENT_ID) fail('GOOGLE_CLIENT_ID is required');
if (!process.env.DATABASE_URL) fail('DATABASE_URL is required');
if (process.env.AUTH_PORTAL_REDIRECT) {
  try {
    const url = new URL(process.env.AUTH_PORTAL_REDIRECT);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      fail('AUTH_PORTAL_REDIRECT must be an absolute http(s) URL');
    }
  } catch {
    fail('AUTH_PORTAL_REDIRECT must be an absolute http(s) URL');
  }
}

const jwt = require('jsonwebtoken');
const { GoogleTokenInvalidError, checkIdentityReady } = require('../src/identity');

function verifyIdToken(idToken, options) {
  let payload;
  try {
    payload = jwt.verify(idToken, FAKE_GOOGLE_SECRET, { algorithms: ['HS256'] });
  } catch {
    throw new GoogleTokenInvalidError();
  }
  const nonce = options && Object.prototype.hasOwnProperty.call(options, 'nonce')
    ? options.nonce
    : undefined;
  if (nonce !== undefined && payload.nonce !== nonce) {
    throw new GoogleTokenInvalidError();
  }
  if (typeof payload.sub !== 'string' || payload.sub.length < 1 || payload.sub.length > 255) {
    throw new GoogleTokenInvalidError();
  }
  const email = typeof payload.email === 'string' && payload.email.length > 0
    ? payload.email
    : null;
  if (email !== null && payload.email_verified !== true) {
    throw new GoogleTokenInvalidError();
  }
  return { googleSub: payload.sub, email };
}

function exchangeAuthCode({ code }) {
  const match = /^fake:([^:]+):([^:]*):([^:]*)$/.exec(typeof code === 'string' ? code : '');
  if (!match) throw new GoogleTokenInvalidError();
  const payload = { sub: match[1], nonce: match[3] };
  if (match[2]) {
    payload.email = match[2];
    payload.email_verified = true;
  }
  return jwt.sign(payload, FAKE_GOOGLE_SECRET, { algorithm: 'HS256' });
}

const { checkReady } = require('../src/db');
const { createServer } = require('../src/app');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = process.env.HOST || '0.0.0.0';

const server = createServer({
  verifyIdToken,
  exchangeAuthCode,
  trustProxyHops: 1,
});

Promise.all([checkReady(), checkIdentityReady()])
  .then(() => {
    server.listen(PORT, HOST, () => {
      console.log(`cestovni-api contract server listening on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('database is not ready:', err.message);
    process.exit(1);
  });
