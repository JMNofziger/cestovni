'use strict';

// Production entry. Validates config, uses the real Google verifier, and listens.
// Contract tests start test-support/contract-server.js instead of this file.

function fail(message) {
  console.error(message);
  process.exit(1);
}

const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) fail('JWT_SECRET is required');
if (jwtSecret.length < 32) fail('JWT_SECRET must be at least 32 characters');
if (!process.env.AUTH_ISSUER_URL) fail('AUTH_ISSUER_URL is required');
if (!process.env.GOOGLE_CLIENT_ID) fail('GOOGLE_CLIENT_ID is required');
if (!process.env.GOOGLE_CLIENT_SECRET) fail('GOOGLE_CLIENT_SECRET is required');
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

const { createGoogleVerifier, exchangeAuthCode, checkIdentityReady } = require('./identity');
const { checkReady } = require('./db');
const { createServer } = require('./app');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = process.env.HOST || '0.0.0.0';

const server = createServer({
  verifyIdToken: createGoogleVerifier({ clientId: process.env.GOOGLE_CLIENT_ID }),
  exchangeAuthCode,
});

Promise.all([checkReady(), checkIdentityReady()])
  .then(() => {
    server.listen(PORT, HOST, () => {
      console.log(`cestovni-api listening on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('database is not ready:', err.message);
    process.exit(1);
  });
