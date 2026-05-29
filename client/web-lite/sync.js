// PWA-lite Phase 2 — sync client (push drain + pull bootstrap).
// Mirrors client/lib/sync/sync_client.dart byte-for-byte on the wire:
//   - envelope: { mutations: [{ mutation_id, table, op, row_id, payload }] }
//   - auth: Authorization: Bearer <token> (no Idempotency-Key header)
//   - retry matrix: docs/specs/pwa-lite-v1.md §"Error codes / retry behavior"
// Spec: docs/specs/pwa-lite-v1.md §5 + §"Constraints from Android".
import {
  put,
  bulkPut,
  outboxBatch,
  deleteFrom,
  hydrateRowVersion,
  getSince,
  setSince,
} from './idb.js';

// ---------------------------------------------------------------------------
// Config — base URL + bearer token.
// ---------------------------------------------------------------------------
export const CESTOVNI_API_BASE = 'http://127.0.0.1:8787';
const TOKEN_KEY = 'cestovni_token';
const DEV_TOKEN = 'dev-cestovni-token';

// `?token=` bootstraps localStorage once (then the param can be dropped).
(function bootstrapTokenFromUrl() {
  try {
    const t = new URLSearchParams(location.search).get('token');
    if (t) localStorage.setItem(TOKEN_KEY, t);
  } catch (_) {
    /* non-browser / no location — ignore */
  }
})();

function apiBase() {
  return CESTOVNI_API_BASE;
}

// Fall back to the dev bearer so a clean checkout flushes against the stub
// without manual setup; real deployments set localStorage / ?token=.
function getToken() {
  try {
    return localStorage.getItem(TOKEN_KEY) || DEV_TOKEN;
  } catch (_) {
    return DEV_TOKEN;
  }
}

// ---------------------------------------------------------------------------
// Retry state — exponential backoff 1s → 30s cap, single shared timer.
// ---------------------------------------------------------------------------
let retryTimer = null;
let retryAttempt = 0;
let flushing = false;

function scheduleRetry(onChange) {
  if (retryTimer) return;
  retryAttempt = Math.min(retryAttempt + 1, 6);
  const delay = Math.min(30000, 1000 * Math.pow(2, retryAttempt - 1));
  retryTimer = setTimeout(() => {
    retryTimer = null;
    flushPush({ onChange });
  }, delay);
}

function clearRetry() {
  retryAttempt = 0;
  if (retryTimer) {
    clearTimeout(retryTimer);
    retryTimer = null;
  }
}

// ---------------------------------------------------------------------------
// Outbox row bookkeeping.
// ---------------------------------------------------------------------------
async function recordError(row, message, { dead = false } = {}) {
  row.attempts = (row.attempts || 0) + 1;
  row.last_error = message;
  if (dead) row.dead = true;
  await put('outbox', row);
}

async function applyResult(row, result) {
  // applied | duplicate → hydrate row_version, drop the outbox row.
  if (result.row_version != null) {
    await hydrateRowVersion(
      row.table,
      row.row_id,
      result.row_version,
      result.server_updated_at,
    );
  }
  await deleteFrom('outbox', row.id);
}

// ---------------------------------------------------------------------------
// Push — drain outbox oldest-first, batch ≤100.
// ---------------------------------------------------------------------------
async function pushBatch() {
  const batch = await outboxBatch(100);
  if (batch.length === 0) return { drained: true, progressed: false };

  const envelope = {
    mutations: batch.map((r) => ({
      mutation_id: r.mutation_id,
      table: r.table,
      op: r.op,
      row_id: r.row_id,
      payload: JSON.parse(r.payload_json),
    })),
  };

  let res;
  try {
    res = await fetch(`${apiBase()}/api/v1/mutations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
      },
      body: JSON.stringify(envelope),
    });
  } catch (e) {
    // transport error (no response) → retriable for the whole batch.
    for (const row of batch) await recordError(row, `transport: ${e.message}`);
    return { retriable: true, progressed: false };
  }

  if (res.status === 200) {
    let body;
    try {
      body = await res.json();
    } catch (_) {
      for (const row of batch) await recordError(row, 'invalid JSON response');
      return { retriable: true, progressed: false };
    }
    const byId = new Map((body.results || []).map((r) => [r.mutation_id, r]));
    let progressed = false;
    for (const row of batch) {
      const r = byId.get(row.mutation_id);
      if (!r) {
        await recordError(row, 'no result for mutation_id');
        continue;
      }
      if (r.status === 'applied' || r.status === 'duplicate') {
        await applyResult(row, r);
        progressed = true;
      } else {
        // rejected → non-retriable, dead-letter (ERROR pill; CES-45 owns UX).
        await recordError(row, (r.error && r.error.message) || 'rejected', {
          dead: true,
        });
        progressed = true; // queue advanced (row no longer pushable)
      }
    }
    return { progressed };
  }

  // Request-level status per retry matrix.
  const retriable = res.status === 401 || res.status === 429 || res.status >= 500;
  const msg = `http ${res.status}`;
  for (const row of batch) await recordError(row, msg, { dead: !retriable });
  return { retriable, progressed: !retriable };
}

// Loop batches until the queue is drained, stalls, or hits a retriable error.
export async function flushPush({ onChange } = {}) {
  if (flushing) return;
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return;
  flushing = true;
  try {
    for (let guard = 0; guard < 100; guard++) {
      const r = await pushBatch();
      if (onChange) await onChange();
      if (r.drained) {
        clearRetry();
        break;
      }
      if (r.retriable) {
        scheduleRetry(onChange);
        break;
      }
      if (!r.progressed) break; // only dead rows remain — nothing to do
      clearRetry();
    }
  } finally {
    flushing = false;
  }
}

// ---------------------------------------------------------------------------
// Pull bootstrap — settings, vehicles, fill_ups since cached cursor.
// ---------------------------------------------------------------------------
async function applyPulledRows(table, rows) {
  if (rows.length === 0) return;
  if (table === 'settings') {
    // PWA-lite reads a single cached settings row under id 'singleton'.
    const latest = rows[rows.length - 1];
    await put('settings', {
      id: 'singleton',
      preferred_distance_unit: latest.preferred_distance_unit || 'km',
      preferred_volume_unit: latest.preferred_volume_unit || 'L',
      currency_code: latest.currency_code || 'EUR',
      timezone: latest.timezone || 'Europe/Prague',
    });
    return;
  }
  // vehicles + fill_ups are keyed by id; server is source of truth.
  await bulkPut(table, rows);
}

async function pullTable(table) {
  let since = await getSince(table);
  for (let guard = 0; guard < 100; guard++) {
    let res;
    try {
      res = await fetch(
        `${apiBase()}/api/v1/changes?table=${table}&since=${since}&limit=200`,
        { headers: { Authorization: `Bearer ${getToken()}` } },
      );
    } catch (_) {
      return; // transport error — try again on next trigger
    }
    if (res.status !== 200) return;
    let body;
    try {
      body = await res.json();
    } catch (_) {
      return;
    }
    await applyPulledRows(table, body.rows || []);
    if (body.next_since != null && body.next_since !== since) {
      since = body.next_since;
      await setSince(table, since);
    }
    if (!body.has_more) break;
  }
}

export async function pullBootstrap({ onChange } = {}) {
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return;
  for (const table of ['settings', 'vehicles', 'fill_ups']) {
    await pullTable(table);
  }
  if (onChange) await onChange();
}

// One-shot online sync: bootstrap caches, then drain the outbox.
export async function syncNow({ onChange } = {}) {
  await pullBootstrap({ onChange });
  await flushPush({ onChange });
}
