'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { GoogleTokenInvalidError } = require('./errors');

const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
const IAT_MAX_AGE_SEC = 10 * 60 + 60;
const REFETCH_MIN_MS = 60 * 1000;

async function defaultFetchJwks() {
  let response;
  try {
    response = await fetch(JWKS_URL, { signal: AbortSignal.timeout(5000) });
  } catch {
    throw new GoogleTokenInvalidError();
  }
  if (!response.ok) {
    try {
      await response.arrayBuffer();
    } catch {
      // Ignore a failed drain. The body is never logged.
    }
    throw new GoogleTokenInvalidError();
  }
  try {
    return await response.json();
  } catch {
    throw new GoogleTokenInvalidError();
  }
}

function createGoogleVerifier({ clientId, fetchJwks, now }) {
  const loadJwks = fetchJwks || defaultFetchJwks;
  const clock = now || Date.now;
  const keysByKid = new Map();
  let lastFetchMs = null;

  async function refreshKeys() {
    let body;
    try {
      body = await loadJwks();
    } catch (err) {
      if (err instanceof GoogleTokenInvalidError) throw err;
      throw new GoogleTokenInvalidError();
    }
    lastFetchMs = clock();
    const keys = body && Array.isArray(body.keys) ? body.keys : [];
    for (const jwk of keys) {
      if (jwk && typeof jwk.kid === 'string' && jwk.kid) {
        keysByKid.set(jwk.kid, jwk);
      }
    }
  }

  async function keyForKid(kid) {
    if (keysByKid.has(kid)) return keysByKid.get(kid);
    const t = clock();
    if (lastFetchMs !== null && t - lastFetchMs < REFETCH_MIN_MS) return null;
    await refreshKeys();
    return keysByKid.get(kid) || null;
  }

  return async function verifyIdToken(idToken, options) {
    const decoded = jwt.decode(idToken, { complete: true });
    const kid = decoded && decoded.header && decoded.header.kid;
    if (typeof kid !== 'string' || !kid) throw new GoogleTokenInvalidError();

    const jwk = await keyForKid(kid);
    if (!jwk) throw new GoogleTokenInvalidError();

    let key;
    try {
      key = crypto.createPublicKey({ key: jwk, format: 'jwk' });
    } catch {
      throw new GoogleTokenInvalidError();
    }

    const nowMs = clock();
    const nowSec = Math.floor(nowMs / 1000);
    let payload;
    try {
      payload = jwt.verify(idToken, key, {
        algorithms: ['RS256'],
        audience: clientId,
        issuer: ISSUERS,
        clockTolerance: 60,
        clockTimestamp: nowSec,
      });
    } catch {
      throw new GoogleTokenInvalidError();
    }

    if (typeof payload.iat !== 'number' || !Number.isFinite(payload.iat)) {
      throw new GoogleTokenInvalidError();
    }
    if (nowSec - payload.iat > IAT_MAX_AGE_SEC) throw new GoogleTokenInvalidError();
    if (payload.iat - nowSec > 60) throw new GoogleTokenInvalidError();

    if (typeof payload.sub !== 'string' || payload.sub.length < 1 || payload.sub.length > 255) {
      throw new GoogleTokenInvalidError();
    }

    const nonce = options && Object.prototype.hasOwnProperty.call(options, 'nonce')
      ? options.nonce
      : undefined;
    if (nonce !== undefined && payload.nonce !== nonce) {
      throw new GoogleTokenInvalidError();
    }

    const email = typeof payload.email === 'string' && payload.email.length > 0
      ? payload.email
      : null;
    if (email !== null && payload.email_verified !== true) {
      throw new GoogleTokenInvalidError();
    }

    return { googleSub: payload.sub, email };
  };
}

async function exchangeAuthCode({ code, codeVerifier, redirectUri }) {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    client_id: process.env.GOOGLE_CLIENT_ID || '',
    client_secret: process.env.GOOGLE_CLIENT_SECRET || '',
    redirect_uri: redirectUri,
    code_verifier: codeVerifier,
  });
  let response;
  try {
    response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body,
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new GoogleTokenInvalidError();
  }
  if (!response.ok) {
    try {
      await response.arrayBuffer();
    } catch {
      // Never log the Google response.
    }
    throw new GoogleTokenInvalidError();
  }
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new GoogleTokenInvalidError();
  }
  if (!payload || typeof payload.id_token !== 'string' || payload.id_token.length === 0) {
    throw new GoogleTokenInvalidError();
  }
  return payload.id_token;
}

module.exports = { createGoogleVerifier, exchangeAuthCode };
