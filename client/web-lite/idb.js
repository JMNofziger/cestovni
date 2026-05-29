// IndexedDB v1 — logical mirror of the Drift schema_version 2 tables used by
// PWA-lite (vehicles, fill_ups, outbox, settings, sync_meta).
// Spec: docs/specs/pwa-lite-v1.md §4. No Drift / OPFS; plain IndexedDB.

const DB_NAME = 'cestovni';
const DB_VERSION = 1;

let dbPromise = null;

function openDb() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (event) => {
      const db = req.result;
      if (!db.objectStoreNames.contains('vehicles')) {
        db.createObjectStore('vehicles', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('fill_ups')) {
        const s = db.createObjectStore('fill_ups', { keyPath: 'id' });
        s.createIndex('vehicle_id', 'vehicle_id', { unique: false });
        s.createIndex('filled_at', 'filled_at', { unique: false });
      }
      if (!db.objectStoreNames.contains('outbox')) {
        const s = db.createObjectStore('outbox', {
          keyPath: 'id',
          autoIncrement: true,
        });
        s.createIndex('row_id', 'row_id', { unique: false });
      }
      if (!db.objectStoreNames.contains('settings')) {
        db.createObjectStore('settings', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('sync_meta')) {
        db.createObjectStore('sync_meta', { keyPath: 'table' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

function tx(db, stores, mode) {
  return db.transaction(stores, mode);
}

function reqToPromise(req) {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function txDone(transaction) {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onabort = () => reject(transaction.error);
    transaction.onerror = () => reject(transaction.error);
  });
}

export async function getAll(store) {
  const db = await openDb();
  return reqToPromise(tx(db, store, 'readonly').objectStore(store).getAll());
}

export async function get(store, key) {
  const db = await openDb();
  return reqToPromise(tx(db, store, 'readonly').objectStore(store).get(key));
}

export async function put(store, value) {
  const db = await openDb();
  const t = tx(db, store, 'readwrite');
  t.objectStore(store).put(value);
  return txDone(t);
}

export async function bulkPut(store, values) {
  const db = await openDb();
  const t = tx(db, store, 'readwrite');
  const os = t.objectStore(store);
  for (const v of values) os.put(v);
  return txDone(t);
}

// Atomic save: write the fill_up row and enqueue its outbox row in ONE
// transaction so the local row and its pending mutation are always consistent.
// Spec: docs/specs/pwa-lite-v1.md §2 "Save flow".
export async function saveFillUpWithOutbox(fillUpRow, outboxRow) {
  const db = await openDb();
  const t = tx(db, ['fill_ups', 'outbox'], 'readwrite');
  t.objectStore('fill_ups').put(fillUpRow);
  t.objectStore('outbox').add(outboxRow);
  return txDone(t);
}

// Returns the set of row_ids that currently have a pending outbox row, so
// History can render the PENDING pill without N queries.
export async function pendingRowIds() {
  const rows = await getAll('outbox');
  return new Set(rows.map((r) => r.row_id));
}

// --------------------------------------------------------------------------
// Phase 2 — sync helpers (push drain, pull upsert, sync_meta, hydrate).
// Spec: docs/specs/pwa-lite-v1.md §5 + §"Constraints from Android".
// --------------------------------------------------------------------------

export async function deleteFrom(store, key) {
  const db = await openDb();
  const t = tx(db, store, 'readwrite');
  t.objectStore(store).delete(key);
  return txDone(t);
}

// sync_meta value shape: { table, last_since }.
export async function getSince(table) {
  const row = await get('sync_meta', table);
  return row ? row.last_since || 0 : 0;
}

export async function setSince(table, lastSince) {
  return put('sync_meta', { table, last_since: lastSince });
}

// Oldest-first batch of pushable outbox rows (dead-lettered rows excluded so
// they neither block the queue nor retry forever). Keyed by autoincrement id,
// which getAll returns in ascending key order — i.e. enqueue order.
export async function outboxBatch(limit = 100) {
  const rows = await getAll('outbox');
  return rows.filter((r) => !r.dead).slice(0, limit);
}

// Classify outbox rows by row_id for History pills + header label.
export async function outboxStates() {
  const rows = await getAll('outbox');
  const pending = new Set();
  const dead = new Set();
  for (const r of rows) {
    if (r.dead) dead.add(r.row_id);
    else pending.add(r.row_id);
  }
  return { pending, dead, count: rows.length };
}

// Hydrate server-assigned row_version (+ updated_at) onto a synced local row.
export async function hydrateRowVersion(store, rowId, rowVersion, serverUpdatedAt) {
  const db = await openDb();
  const t = tx(db, store, 'readwrite');
  const os = t.objectStore(store);
  const existing = await reqToPromise(os.get(rowId));
  if (existing) {
    existing.row_version = rowVersion;
    if (serverUpdatedAt) existing.updated_at = serverUpdatedAt;
    os.put(existing);
  }
  return txDone(t);
}

export async function fillUpsForVehicle(vehicleId) {
  const db = await openDb();
  const index = tx(db, 'fill_ups', 'readonly')
    .objectStore('fill_ups')
    .index('vehicle_id');
  const rows = await reqToPromise(index.getAll(IDBKeyRange.only(vehicleId)));
  // filled_at DESC, then id DESC (matches FillUpsRepository.watchForVehicle).
  rows.sort((a, b) => {
    if (a.filled_at !== b.filled_at) {
      return a.filled_at < b.filled_at ? 1 : -1;
    }
    return a.id < b.id ? 1 : -1;
  });
  return rows;
}
