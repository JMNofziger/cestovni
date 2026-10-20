'use strict';

// Cestovni app-owned sync API (CES-43).
//
// POST /api/v1/mutations
// GET  /api/v1/changes
// GET  /api/v1/restore/manifest
// GET  /healthz
//
// Every authenticated request runs as cestovni_app with
// set_config('app.user_id', <jwt sub>, true) so RLS sees auth_user_id().

const http = require('http');

const { userIdFromRequest, AuthError } = require('./auth');
const { withUser, checkReady } = require('./db');
const { applyBatch } = require('./mutations');
const { listChanges, restoreManifest } = require('./read');
const { mutationLimiter, changesLimiter } = require('./rate-limit');
const { TABLES } = require('./schema');

const PORT = parseInt(process.env.PORT || '8080', 10);
const HOST = process.env.HOST || '0.0.0.0';
const JWT_SECRET = process.env.JWT_SECRET;
const MAX_BODY = 1024 * 1024;
const MAX_BATCH = 100;

if (!JWT_SECRET) {
  console.error('JWT_SECRET is required');
  process.exit(1);
}
if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}

function corsOrigin(req) {
  const configured = (process.env.CORS_ORIGINS || '*').trim();
  const origin = req.headers.origin;
  if (configured === '*') return origin || '*';
  const allowed = configured.split(',').map((s) => s.trim()).filter(Boolean);
  if (origin && allowed.includes(origin)) return origin;
  return null;
}

function setCors(req, res) {
  const origin = corsOrigin(req);
  if (origin) res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
}

function sendJson(res, status, body, extraHeaders) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(json),
    'Cache-Control': 'no-store',
    ...(extraHeaders || {}),
  });
  res.end(json);
}

function sendError(res, status, code, message, retriable, extraHeaders) {
  sendJson(res, status, { error: { code, message, retriable } }, extraHeaders);
}

function readBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let settled = false;
    let total = 0;
    const chunks = [];
    const fail = (err) => {
      if (settled) return;
      settled = true;
      reject(err);
    };
    const ok = (buf) => {
      if (settled) return;
      settled = true;
      resolve(buf);
    };
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        const err = new Error('body exceeds 1 MiB');
        err.status = 413;
        err.code = 'payload_too_large';
        err.retriable = false;
        fail(err);
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => ok(Buffer.concat(chunks)));
    req.on('error', (err) => {
      if (err.code === 'ECONNRESET') return;
      fail(err);
    });
  });
}

function parseSince(raw) {
  if (raw == null || raw === '') return 0;
  if (!/^\d+$/.test(raw)) {
    const err = new Error('since must be a non-negative integer');
    err.status = 400;
    err.code = 'bad_request';
    err.retriable = false;
    throw err;
  }
  return Number(raw);
}

function parseLimit(raw) {
  if (raw == null || raw === '') return { limit: 200, clamped: false };
  if (!/^\d+$/.test(raw) || Number(raw) < 1) {
    const err = new Error('limit must be a positive integer');
    err.status = 400;
    err.code = 'bad_request';
    err.retriable = false;
    throw err;
  }
  const requested = Number(raw);
  if (requested > 500) return { limit: 500, clamped: true };
  return { limit: requested, clamped: false };
}

async function handleMutations(req, res, userId) {
  const declared = Number(req.headers['content-length'] || 0);
  if (Number.isFinite(declared) && declared > MAX_BODY) {
    req.resume();
    return sendError(res, 413, 'payload_too_large', 'body exceeds 1 MiB', false);
  }
  let raw;
  try {
    raw = await readBody(req, MAX_BODY);
  } catch (err) {
    if (err.status === 413) {
      return sendError(res, 413, 'payload_too_large', err.message, false);
    }
    throw err;
  }
  let body;
  try {
    body = JSON.parse(raw.toString('utf8') || '');
  } catch (_) {
    return sendError(res, 400, 'bad_request', 'invalid JSON body', false);
  }
  const mutations = body && body.mutations;
  if (!Array.isArray(mutations)) {
    return sendError(res, 400, 'bad_request', 'missing "mutations" array', false);
  }
  if (mutations.length > MAX_BATCH) {
    return sendError(res, 413, 'batch_too_large', 'batch exceeds 100 mutations', false);
  }
  const quota = mutationLimiter.take(userId, mutations.length);
  if (!quota.ok) {
    return sendError(res, 429, 'rate_limited', 'mutation rate limit exceeded', true, {
      'Retry-After': String(quota.retryAfter),
    });
  }
  const results = await withUser(userId, (client) => applyBatch(client, mutations));
  return sendJson(res, 200, { results });
}

async function handleChanges(req, res, userId, url) {
  const table = url.searchParams.get('table');
  if (!table || !TABLES[table]) {
    return sendError(res, 400, 'bad_request', 'missing or unknown ?table=', false);
  }
  const since = parseSince(url.searchParams.get('since'));
  const { limit, clamped } = parseLimit(url.searchParams.get('limit'));
  const quota = changesLimiter.take(userId, 1);
  if (!quota.ok) {
    return sendError(res, 429, 'rate_limited', 'changes rate limit exceeded', true, {
      'Retry-After': String(quota.retryAfter),
    });
  }
  const body = await withUser(userId, (client) => listChanges(client, table, since, limit));
  const headers = clamped ? { 'X-Limit-Clamped': 'true' } : undefined;
  return sendJson(res, 200, body, headers);
}

async function handleManifest(req, res, userId) {
  const quota = changesLimiter.take(userId, 1);
  if (!quota.ok) {
    return sendError(res, 429, 'rate_limited', 'changes rate limit exceeded', true, {
      'Retry-After': String(quota.retryAfter),
    });
  }
  const body = await withUser(userId, (client) => restoreManifest(client));
  return sendJson(res, 200, body);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  setCors(req, res);
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  try {
    if (req.method === 'GET' && url.pathname === '/healthz') {
      await checkReady();
      return sendJson(res, 200, { ok: true });
    }

    let userId;
    try {
      userId = userIdFromRequest(req, JWT_SECRET);
    } catch (err) {
      if (err instanceof AuthError) {
        return sendError(res, 401, err.code, err.message, false);
      }
      throw err;
    }

    if (req.method === 'POST' && url.pathname === '/api/v1/mutations') {
      return await handleMutations(req, res, userId);
    }
    if (req.method === 'GET' && url.pathname === '/api/v1/changes') {
      return await handleChanges(req, res, userId, url);
    }
    if (req.method === 'GET' && url.pathname === '/api/v1/restore/manifest') {
      return await handleManifest(req, res, userId);
    }
    return sendError(res, 404, 'not_found', `${req.method} ${url.pathname}`, false);
  } catch (err) {
    if (err.status === 400 || err.status === 413) {
      return sendError(res, err.status, err.code || 'bad_request', err.message, false);
    }
    console.error(err);
    if (!res.headersSent) {
      return sendError(res, 500, 'internal', 'internal error', true);
    }
    res.destroy();
  }
});

checkReady()
  .then(() => {
    server.listen(PORT, HOST, () => {
      console.log(`cestovni-api listening on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('database is not ready:', err.message);
    process.exit(1);
  });
