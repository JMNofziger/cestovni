#!/usr/bin/env node
// Cestovni dev sync stub — CES-43 minimal slice for the PWA-lite gate.
//
// Implements two endpoints from docs/specs/sync-protocol.md:
//   - POST /api/v1/mutations  (batch upload; status: applied|duplicate|rejected)
//   - GET  /api/v1/changes    (paginated catch-up stream)
//
// In-memory only, single dev user. Zero npm dependencies — uses Node's
// built-in `http` so the stub runs with `node server.js` straight from
// a clean checkout. NOT production-shaped: no RLS, no real JWT, no
// persistence across restarts.
//
// Auth: trivial bearer check against DEV_BEARER_TOKEN (default
// "dev-cestovni-token"). Real JWT/OIDC is CES-43 proper — out of scope
// for the gate slice.

'use strict';

const http = require('http');
const { URL } = require('url');

const PORT = parseInt(process.env.PORT || '8787', 10);
const BEARER = process.env.DEV_BEARER_TOKEN || 'dev-cestovni-token';
const DEV_USER_ID = 'dev-user-0000-0000-000000000000';

// row_version is a monotonic per-batch sequence shared across tables
// (mirrors `cestovni_row_version_seq` from the spec).
let rowVersionSeq = 0;
function nextRowVersion() {
  return ++rowVersionSeq;
}

// Per-table storage: Map<row_id, row>. `row` carries protocol columns
// plus the original payload columns merged on top.
const tables = {
  fill_ups: new Map(),
  vehicles: new Map(),
  settings: new Map(),
  maintenance_rules: new Map(),
  maintenance_events: new Map(),
};

// Idempotency map: mutation_id -> { row_id, row_version, server_updated_at, status, table }
const mutationLog = new Map();

function nowIso() {
  return new Date().toISOString();
}

function sendJson(res, status, body) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(json),
    'Cache-Control': 'no-store',
  });
  res.end(json);
}

function sendError(res, status, code, message, { retriable = false } = {}) {
  sendJson(res, status, { error: { code, message, retriable } });
}

function checkAuth(req, res) {
  const header = req.headers['authorization'] || '';
  if (!header.toLowerCase().startsWith('bearer ')) {
    sendError(res, 401, 'unauthenticated', 'missing bearer token');
    return false;
  }
  const token = header.slice(7).trim();
  if (token !== BEARER) {
    sendError(res, 401, 'unauthenticated', 'invalid bearer token');
    return false;
  }
  return true;
}

async function readBody(req, { maxBytes = 1024 * 1024 } = {}) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(Object.assign(new Error('payload too large'), { code: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function applyMutation(mutation) {
  const { mutation_id, table, op, row_id, payload } = mutation;

  if (!mutation_id || !table || !op || !row_id) {
    return {
      mutation_id,
      row_id,
      status: 'rejected',
      error: {
        code: 'invalid_argument',
        message: 'missing mutation_id, table, op, or row_id',
        retriable: false,
      },
    };
  }

  if (!tables[table]) {
    return {
      mutation_id,
      row_id,
      status: 'rejected',
      error: {
        code: 'invalid_argument',
        message: `unknown table: ${table}`,
        retriable: false,
      },
    };
  }

  // Idempotent retry: same mutation_id → return original outcome.
  if (mutationLog.has(mutation_id)) {
    const cached = mutationLog.get(mutation_id);
    return {
      mutation_id,
      row_id: cached.row_id,
      row_version: cached.row_version,
      server_updated_at: cached.server_updated_at,
      status: 'duplicate',
    };
  }

  const store = tables[table];
  const serverUpdatedAt = nowIso();
  const rowVersion = nextRowVersion();

  if (op === 'insert' || op === 'update') {
    if (!payload || typeof payload !== 'object') {
      return {
        mutation_id,
        row_id,
        status: 'rejected',
        error: {
          code: 'invalid_argument',
          message: `${op} requires a payload object`,
          retriable: false,
        },
      };
    }
    const merged = {
      ...(store.get(row_id) || {}),
      ...payload,
      id: row_id,
      user_id: DEV_USER_ID,
      row_version: rowVersion,
      updated_at: serverUpdatedAt,
      mutation_id,
      deleted_at: payload.deleted_at || null,
    };
    store.set(row_id, merged);
  } else if (op === 'soft_delete') {
    const existing = store.get(row_id);
    if (!existing) {
      // Allow soft-delete-before-insert in dev — record a tombstone so
      // `GET /changes` still reports it.
      store.set(row_id, {
        id: row_id,
        user_id: DEV_USER_ID,
        row_version: rowVersion,
        updated_at: serverUpdatedAt,
        deleted_at: serverUpdatedAt,
        mutation_id,
      });
    } else {
      store.set(row_id, {
        ...existing,
        row_version: rowVersion,
        updated_at: serverUpdatedAt,
        deleted_at: serverUpdatedAt,
        mutation_id,
      });
    }
  } else {
    return {
      mutation_id,
      row_id,
      status: 'rejected',
      error: {
        code: 'invalid_argument',
        message: `unknown op: ${op}`,
        retriable: false,
      },
    };
  }

  const outcome = {
    row_id,
    row_version: rowVersion,
    server_updated_at: serverUpdatedAt,
    status: 'applied',
    table,
  };
  mutationLog.set(mutation_id, outcome);
  return {
    mutation_id,
    row_id,
    row_version: rowVersion,
    server_updated_at: serverUpdatedAt,
    status: 'applied',
  };
}

async function handleMutations(req, res) {
  let raw;
  try {
    raw = await readBody(req);
  } catch (err) {
    if (err.code === 413) {
      return sendError(res, 413, 'payload_too_large', 'body exceeds 1 MiB');
    }
    return sendError(res, 400, 'bad_request', err.message);
  }

  let body;
  try {
    body = JSON.parse(raw);
  } catch (err) {
    return sendError(res, 400, 'bad_request', 'invalid JSON body');
  }

  const mutations = Array.isArray(body && body.mutations) ? body.mutations : null;
  if (!mutations) {
    return sendError(res, 400, 'bad_request', 'missing "mutations" array');
  }
  if (mutations.length > 100) {
    return sendError(res, 413, 'batch_too_large', 'batch exceeds 100 mutations');
  }

  const results = mutations.map(applyMutation);
  return sendJson(res, 200, { results });
}

function handleChanges(req, res, parsed) {
  const table = parsed.searchParams.get('table');
  if (!table || !tables[table]) {
    return sendError(res, 400, 'bad_request', 'missing or unknown ?table=');
  }
  const since = parseInt(parsed.searchParams.get('since') || '0', 10) || 0;
  const limit = Math.min(
    parseInt(parsed.searchParams.get('limit') || '200', 10) || 200,
    500,
  );

  const all = Array.from(tables[table].values())
    .filter((r) => r.row_version > since)
    .sort((a, b) => a.row_version - b.row_version);
  const page = all.slice(0, limit);
  const has_more = all.length > page.length;
  const next_since = page.length
    ? page[page.length - 1].row_version
    : since;

  return sendJson(res, 200, {
    table,
    rows: page,
    next_since,
    has_more,
  });
}

// Permissive CORS for local dev + Cloudflare Pages previews. The PWA-lite
// client runs from a different origin (file://localhost http server, Pages
// preview URL) than the stub, so browser fetch() needs these headers and a
// preflight handler. Not production-shaped — real CES-43 backend pins origins.
function setCors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
}

const server = http.createServer(async (req, res) => {
  const parsed = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = parsed.pathname;

  setCors(req, res);
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  if (req.method === 'GET' && path === '/healthz') {
    return sendJson(res, 200, { ok: true, row_version: rowVersionSeq });
  }

  if (!checkAuth(req, res)) return;

  if (req.method === 'POST' && path === '/api/v1/mutations') {
    return handleMutations(req, res);
  }
  if (req.method === 'GET' && path === '/api/v1/changes') {
    return handleChanges(req, res, parsed);
  }
  return sendError(res, 404, 'not_found', `${req.method} ${path}`);
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(
    `cestovni dev-sync-stub listening on http://127.0.0.1:${PORT} ` +
      `(bearer="${BEARER}")`,
  );
});
