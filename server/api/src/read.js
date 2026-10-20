'use strict';

const { TABLE_NAMES, TABLES, quoteIdent } = require('./schema');

function serializeRow(row) {
  const out = {};
  for (const [key, value] of Object.entries(row)) {
    out[key] = value instanceof Date ? value.toISOString() : value;
  }
  return out;
}

async function listChanges(client, table, since, limit) {
  if (!TABLES[table]) {
    const err = new Error(`unknown table: ${table}`);
    err.status = 400;
    err.code = 'bad_request';
    err.retriable = false;
    throw err;
  }
  const res = await client.query(
    `SELECT * FROM ${quoteIdent(table)}
      WHERE row_version > $1
      ORDER BY row_version ASC
      LIMIT $2`,
    [since, limit + 1],
  );
  const hasMore = res.rows.length > limit;
  const page = hasMore ? res.rows.slice(0, limit) : res.rows;
  return {
    table,
    rows: page.map(serializeRow),
    next_since: page.length ? page[page.length - 1].row_version : since,
    has_more: hasMore,
  };
}

async function restoreManifest(client) {
  const tables = [];
  for (const table of TABLE_NAMES) {
    const res = await client.query(
      `SELECT count(*)::int AS row_count,
              max(row_version) AS max_row_version
         FROM ${quoteIdent(table)}`,
    );
    tables.push({
      table,
      row_count: res.rows[0].row_count,
      max_row_version: res.rows[0].max_row_version ?? 0,
    });
  }
  return { tables };
}

module.exports = { listChanges, restoreManifest };
