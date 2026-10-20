'use strict';

const { TABLES, quoteIdent } = require('./schema');
const { iso } = require('./db');

const OPS = new Set(['insert', 'update', 'soft_delete']);
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function rejected(mutationId, rowId, code, message) {
  return {
    mutation_id: mutationId ?? null,
    row_id: rowId ?? null,
    status: 'rejected',
    error: { code, message, retriable: false },
  };
}

function appliedLike(mutationId, rowId, rowVersion, updatedAt, status) {
  return {
    mutation_id: mutationId,
    row_id: rowId,
    row_version: rowVersion,
    server_updated_at: iso(updatedAt),
    status,
  };
}

function dbRejection(mutationId, rowId, err) {
  const codes = {
    '23514': 'constraint_violation',
    '23502': 'not_null_violation',
    '23503': 'foreign_key_violation',
    '23505': 'unique_violation',
    '22P02': 'invalid_input',
    '22007': 'invalid_datetime',
    '22003': 'numeric_out_of_range',
    '42501': 'forbidden',
  };
  const code = codes[err.code];
  if (!code) throw err;
  return rejected(mutationId, rowId, code, err.message);
}

async function lockRow(client, table, rowId) {
  await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [
    `${table}:${rowId}`,
  ]);
}

async function findByMutation(client, table, mutationId) {
  const res = await client.query(
    `SELECT id, row_version, updated_at FROM ${quoteIdent(table)} WHERE mutation_id = $1`,
    [mutationId],
  );
  return res.rows[0] || null;
}

async function findById(client, table, rowId) {
  const res = await client.query(
    `SELECT id, mutation_id, row_version, updated_at FROM ${quoteIdent(table)} WHERE id = $1`,
    [rowId],
  );
  return res.rows[0] || null;
}

function payloadColumns(table, payload) {
  const spec = TABLES[table];
  const allowed = new Set(spec.columns);
  const entries = [];
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) continue;
    entries.push([key, payload[key]]);
  }
  return entries;
}

function missingRequired(table, payload) {
  const missing = TABLES[table].requiredOnInsert.filter(
    (col) => payload[col] === undefined,
  );
  return missing;
}

async function insertRow(client, table, rowId, mutationId, payload) {
  const entries = payloadColumns(table, payload);
  const cols = ['id', 'user_id', 'mutation_id', ...entries.map(([k]) => k)];
  const params = [rowId, mutationId, ...entries.map(([, v]) => v)];
  // $1 id, auth_user_id() (not a parameter), $2 mutation_id, then payload.
  const values = ['$1', 'auth_user_id()', '$2'];
  entries.forEach((_, i) => values.push(`$${i + 3}`));
  const sql = `
    INSERT INTO ${quoteIdent(table)} (${cols.map(quoteIdent).join(', ')})
    VALUES (${values.join(', ')})
    RETURNING id, row_version, updated_at
  `;
  const res = await client.query(sql, params);
  return res.rows[0];
}

async function updateRow(client, table, rowId, mutationId, payload) {
  const entries = payloadColumns(table, payload);
  const sets = ['mutation_id = $2'];
  const params = [rowId, mutationId];
  entries.forEach(([key, value]) => {
    params.push(value);
    sets.push(`${quoteIdent(key)} = $${params.length}`);
  });
  const sql = `
    UPDATE ${quoteIdent(table)}
       SET ${sets.join(', ')}
     WHERE id = $1
    RETURNING id, row_version, updated_at
  `;
  const res = await client.query(sql, params);
  return res.rows[0] || null;
}

async function softDeleteRow(client, table, rowId, mutationId) {
  const sql = `
    UPDATE ${quoteIdent(table)}
       SET deleted_at = now(), mutation_id = $2
     WHERE id = $1
    RETURNING id, row_version, updated_at
  `;
  const res = await client.query(sql, [rowId, mutationId]);
  return res.rows[0] || null;
}

async function applyOne(client, mutation) {
  const mutationId = mutation && mutation.mutation_id;
  const table = mutation && mutation.table;
  const op = mutation && mutation.op;
  const rowId = mutation && mutation.row_id;

  if (!mutationId || !table || !op || !rowId) {
    return rejected(
      mutationId,
      rowId,
      'invalid_argument',
      'missing mutation_id, table, op, or row_id',
    );
  }
  if (!UUID_RE.test(String(mutationId)) || !UUID_RE.test(String(rowId))) {
    return rejected(mutationId, rowId, 'invalid_argument', 'mutation_id and row_id must be uuids');
  }
  if (!TABLES[table]) {
    return rejected(mutationId, rowId, 'unknown_table', `unknown table: ${table}`);
  }
  if (!OPS.has(op)) {
    return rejected(mutationId, rowId, 'invalid_argument', `unknown op: ${op}`);
  }

  const payload =
    mutation.payload === undefined || mutation.payload === null
      ? {}
      : mutation.payload;
  if (op !== 'soft_delete') {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return rejected(mutationId, rowId, 'invalid_argument', `${op} requires a payload object`);
    }
    if (payload.id !== undefined && payload.id !== rowId) {
      return rejected(mutationId, rowId, 'invalid_argument', 'payload.id does not match row_id');
    }
  }

  await lockRow(client, table, rowId);

  const prior = await findByMutation(client, table, mutationId);
  if (prior) {
    return appliedLike(mutationId, prior.id, prior.row_version, prior.updated_at, 'duplicate');
  }

  if (op === 'insert') {
    const missing = missingRequired(table, payload);
    if (missing.length) {
      return rejected(
        mutationId,
        rowId,
        'invalid_argument',
        `missing payload fields: ${missing.join(', ')}`,
      );
    }
    const existing = await findById(client, table, rowId);
    if (existing) {
      return rejected(mutationId, rowId, 'already_exists', 'row id already exists');
    }
    const row = await insertRow(client, table, rowId, mutationId, payload);
    return appliedLike(mutationId, row.id, row.row_version, row.updated_at, 'applied');
  }

  const existing = await findById(client, table, rowId);
  if (!existing) {
    return rejected(mutationId, rowId, 'not_found', 'row not found');
  }
  const row =
    op === 'soft_delete'
      ? await softDeleteRow(client, table, rowId, mutationId)
      : await updateRow(client, table, rowId, mutationId, payload);
  if (!row) {
    return rejected(mutationId, rowId, 'not_found', 'row not found');
  }
  return appliedLike(mutationId, row.id, row.row_version, row.updated_at, 'applied');
}

async function applyBatch(client, mutations) {
  const results = [];
  for (let i = 0; i < mutations.length; i += 1) {
    const mutation = mutations[i];
    const save = `ces_m_${i}`;
    await client.query(`SAVEPOINT ${save}`);
    try {
      const result = await applyOne(client, mutation);
      await client.query(`RELEASE SAVEPOINT ${save}`);
      results.push(result);
    } catch (err) {
      await client.query(`ROLLBACK TO SAVEPOINT ${save}`);
      results.push(
        dbRejection(
          mutation && mutation.mutation_id,
          mutation && mutation.row_id,
          err,
        ),
      );
    }
  }
  return results;
}

module.exports = { applyBatch };
