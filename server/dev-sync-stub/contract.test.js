#!/usr/bin/env node
// Contract test for the dev sync stub — mirrors the PWA-lite push/pull round
// trip: POST a fill_ups insert, read it back via GET /changes, and confirm
// idempotency (same mutation_id → duplicate). Zero deps; run with:
//   node server/dev-sync-stub/contract.test.js
// Exits 0 on pass, 1 on failure. Not wired into CI (Flutter/Python gates only).

'use strict';

const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const PORT = 8799;
const BASE = `http://127.0.0.1:${PORT}`;
const TOKEN = 'dev-cestovni-token';

// Reference gate E2E IDs (docs/specs/pwa-lite-v1.md §Existing Decisions).
const ROW_ID = '2ed68a63-2347-4813-9d6e-f903426fa705';
const MUTATION_ID = '3b7cea29-7e59-4d11-8842-fe563149b9bf';

function request(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const req = http.request(
      `${BASE}${urlPath}`,
      {
        method,
        headers: {
          Authorization: `Bearer ${TOKEN}`,
          'Content-Type': 'application/json',
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () =>
          resolve({ status: res.statusCode, json: raw ? JSON.parse(raw) : null }),
        );
      },
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function assert(cond, msg) {
  if (!cond) throw new Error(`ASSERT FAILED: ${msg}`);
}

async function waitForHealth(retries = 50) {
  for (let i = 0; i < retries; i++) {
    try {
      const r = await request('GET', '/healthz');
      if (r.status === 200) return;
    } catch (_) {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('stub did not become healthy');
}

const mutation = {
  mutation_id: MUTATION_ID,
  table: 'fill_ups',
  op: 'insert',
  row_id: ROW_ID,
  payload: {
    id: ROW_ID,
    vehicle_id: '33333333-3333-3333-3333-333333333333',
    filled_at: '2026-05-29T10:00:00.000Z',
    odometer_m: 123456000,
    volume_uL: 41500000,
    total_price_cents: 5876,
    currency_code: 'EUR',
    is_full: true,
    missed_before: false,
    odometer_reset: false,
    notes: null,
    updated_at: '2026-05-29T10:00:00.000Z',
    deleted_at: null,
    mutation_id: '44444444-4444-4444-4444-444444444444',
  },
};

async function main() {
  const server = spawn('node', [path.join(__dirname, 'server.js')], {
    env: { ...process.env, PORT: String(PORT), DEV_BEARER_TOKEN: TOKEN },
    stdio: 'ignore',
  });

  try {
    await waitForHealth();

    // 1. Push insert → applied with a server row_version.
    const push = await request('POST', '/api/v1/mutations', {
      mutations: [mutation],
    });
    assert(push.status === 200, `push status ${push.status}`);
    const r1 = push.json.results[0];
    assert(r1.status === 'applied', `expected applied, got ${r1.status}`);
    assert(typeof r1.row_version === 'number', 'row_version assigned');

    // 2. Pull → row visible via /changes.
    const pull = await request('GET', '/api/v1/changes?table=fill_ups&since=0');
    assert(pull.status === 200, `pull status ${pull.status}`);
    const found = pull.json.rows.find((row) => row.id === ROW_ID);
    assert(found, 'row_id present in /changes');
    assert(found.row_version === r1.row_version, 'row_version matches');

    // 3. Retry same mutation_id → duplicate, same row_version (idempotent).
    const retry = await request('POST', '/api/v1/mutations', {
      mutations: [mutation],
    });
    const r2 = retry.json.results[0];
    assert(r2.status === 'duplicate', `expected duplicate, got ${r2.status}`);
    assert(r2.row_version === r1.row_version, 'duplicate keeps row_version');

    console.log(
      `PASS — mutation_id=${MUTATION_ID} row_id=${ROW_ID} ` +
        `row_version=${r1.row_version} (applied → duplicate)`,
    );
  } finally {
    server.kill();
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exitCode = 1;
});
