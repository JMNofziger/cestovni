'use strict';

// Test-side fake Google ID tokens. Contract tests must not import server code.
// FAKE_GOOGLE_SECRET must match the constant in server/api/test-support/contract-server.js.

const path = require('path');
const jwt = require(path.join(__dirname, '../../server/api/node_modules/jsonwebtoken'));

const FAKE_GOOGLE_SECRET = 'ces83-contract-fake-google-secret';

function fakeIdToken({ sub, email, nonce, emailVerified } = {}) {
  const payload = { sub };
  if (email != null) payload.email = email;
  if (emailVerified != null) payload.email_verified = emailVerified;
  else if (email) payload.email_verified = true;
  if (nonce != null) payload.nonce = nonce;
  return jwt.sign(payload, FAKE_GOOGLE_SECRET, { algorithm: 'HS256' });
}

function fakeCode({ sub, email, nonce } = {}) {
  return `fake:${sub}:${email == null ? '' : email}:${nonce == null ? '' : nonce}`;
}

module.exports = { FAKE_GOOGLE_SECRET, fakeIdToken, fakeCode };
