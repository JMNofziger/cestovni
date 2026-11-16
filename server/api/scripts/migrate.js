'use strict';

// CES-80 migration runner.
//
// Applies db/migrations/*.sql in filename order and records the four-digit
// version in schema_migrations. The API process never calls this.
//
// No checksums: an edited, already-applied file is not detected in v1.
// No down migrations. Hardening is CES-95.
//
// DATABASE_URL (superuser or equivalent) is required.
// MIGRATIONS_DIR overrides the directory. The default is <repo>/db/migrations
// resolved from this file, not from the process cwd.
// --baseline 0001 records version 0001 without running that file when its
// objects are already present, then applies anything still pending.
//
// Exit 0 success or no-op, 1 migration or baseline failure, 2 usage or config.

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

// One session lock for every runner on a database. A second process waits,
// then sees the first process's schema_migrations rows.
const ADVISORY_LOCK_KEY = 74808080;

const NAME_RE = /^\d{4}_[a-z0-9_]+\.sql$/;

function failConfig(message) {
  const err = new Error(message);
  err.exitCode = 2;
  throw err;
}

function parseBaseline(argv) {
  let baseline = null;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--baseline') {
      const value = argv[i + 1];
      if (!value) failConfig('FAIL: --baseline requires a version');
      if (value !== '0001') failConfig('FAIL: --baseline accepts only 0001');
      baseline = value;
      i += 1;
      continue;
    }
    failConfig(`FAIL: unknown argument ${arg}`);
  }
  return baseline;
}

function readMigrationFiles(dir) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    failConfig(`FAIL: cannot read MIGRATIONS_DIR (${err.code || 'error'})`);
  }
  const names = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name)
    .sort();
  const seen = new Map();
  const files = [];
  for (const name of names) {
    if (!NAME_RE.test(name)) {
      failConfig(`FAIL: migration file ${name} does not match NNNN_name.sql`);
    }
    const version = name.slice(0, 4);
    if (seen.has(version)) {
      failConfig(
        `FAIL: duplicate migration version ${version} (${seen.get(version)}, ${name})`
      );
    }
    seen.set(version, name);
    files.push({ name, version, path: path.join(dir, name) });
  }
  return files;
}

function failingText(sql, position) {
  const pos = Number(position);
  if (!Number.isInteger(pos) || pos < 1) return sql.slice(0, 200);
  const index = Math.min(pos - 1, sql.length);
  const start = sql.slice(0, index).lastIndexOf('\n') + 1;
  const newline = sql.indexOf('\n', index);
  const end = newline === -1 ? sql.length : newline;
  const line = sql.slice(start, end).replace(/\s+$/, '');
  if (line.trim()) return line;
  return sql.slice(0, 200);
}

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  await client.query('REVOKE ALL ON schema_migrations FROM PUBLIC');
}

async function applyBaseline(client, version) {
  const existing = await client.query(
    'SELECT 1 FROM schema_migrations WHERE version = $1',
    [version]
  );
  if (existing.rowCount > 0) {
    console.log(`baseline ${version}: already recorded`);
    return 0;
  }
  const check = await client.query(
    `SELECT to_regclass('public.vehicles') IS NOT NULL
        AND to_regprocedure('auth_user_id()') IS NOT NULL AS ok`
  );
  if (!check.rows[0].ok) {
    console.error(
      'FAIL: baseline 0001 requested but 0001 objects are not in this database'
    );
    return 1;
  }
  await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [version]);
  console.log(`baselined ${version}`);
  return 0;
}

async function applyPending(client, files) {
  const recordedResult = await client.query('SELECT version FROM schema_migrations');
  const recorded = new Set(recordedResult.rows.map((row) => row.version));
  const onDisk = new Set(files.map((file) => file.version));
  for (const version of recorded) {
    if (!onDisk.has(version)) {
      console.error(`WARN: recorded version ${version} has no file on disk`);
    }
  }

  let applied = 0;
  let already = 0;
  for (const file of files) {
    if (recorded.has(file.version)) {
      already += 1;
      continue;
    }
    const sql = fs.readFileSync(file.path, 'utf8');
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [file.version]
      );
      await client.query('COMMIT');
    } catch (err) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {
        // The transaction is already aborted, or the connection is gone.
      }
      console.error(`FAIL: ${file.name}`);
      console.error(`SQLSTATE: ${err.code || 'unknown'}`);
      console.error(err.message || String(err));
      console.error(failingText(sql, err.position));
      return 1;
    }
    console.log(`applied ${file.name}`);
    applied += 1;
    recorded.add(file.version);
  }
  console.log(`migrate: ${applied} applied, ${already} already recorded`);
  return 0;
}

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('FAIL: DATABASE_URL is required');
    return 2;
  }

  let baseline;
  let files;
  try {
    baseline = parseBaseline(process.argv.slice(2));
    const dir = process.env.MIGRATIONS_DIR
      ? path.resolve(process.env.MIGRATIONS_DIR)
      : path.resolve(__dirname, '../../../db/migrations');
    files = readMigrationFiles(dir);
  } catch (err) {
    console.error(err.message);
    return err.exitCode || 2;
  }

  const client = new Client({ connectionString: process.env.DATABASE_URL });
  let locked = false;
  try {
    await client.connect();
    await client.query('SELECT pg_advisory_lock($1::bigint)', [ADVISORY_LOCK_KEY]);
    locked = true;
    await ensureMigrationsTable(client);
    if (baseline) {
      const code = await applyBaseline(client, baseline);
      if (code !== 0) return code;
    }
    return await applyPending(client, files);
  } catch (err) {
    const state = err.code ? `SQLSTATE: ${err.code} ` : '';
    console.error(`FAIL: ${state}${err.message || err}`);
    return 1;
  } finally {
    if (locked) {
      try {
        await client.query('SELECT pg_advisory_unlock($1::bigint)', [ADVISORY_LOCK_KEY]);
      } catch (_) {
        // Unlock is best-effort. Session end releases the lock too.
      }
    }
    try {
      await client.end();
    } catch (_) {
      // Already closed.
    }
  }
}

main()
  .then((code) => {
    process.exit(code);
  })
  .catch((err) => {
    console.error(`FAIL: ${err.message || err}`);
    process.exit(1);
  });
