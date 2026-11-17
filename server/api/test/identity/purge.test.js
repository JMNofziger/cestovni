'use strict';

const assert = require('node:assert/strict');
const crypto = require('crypto');
const { after, before, describe, test } = require('node:test');
const { pool } = require('../../src/db');
const { quoteIdent, TABLES } = require('../../src/schema');
const {
  PURGE_ORDER,
  createLoginCode,
  findOrCreateUser,
  purgeUser,
} = require('../../src/identity');

const PREFIX = 'ces85-';

function failSet(label, missing) {
  const message = `${label}: missing ${missing.join(', ')}`;
  console.error(message);
  assert.fail(message);
}

async function productCounts(userId) {
  const counts = {};
  for (const table of PURGE_ORDER) {
    const res = await pool.query(
      `SELECT count(*)::int AS n FROM ${quoteIdent(table)} WHERE user_id = $1`,
      [userId],
    );
    counts[table] = res.rows[0].n;
  }
  return counts;
}

async function seedProduct(userId, softDeleteVehicle) {
  const vehicleId = crypto.randomUUID();
  await pool.query(
    `INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type, deleted_at)
     VALUES ($1, $2, $3, $4, 'diesel', $5)`,
    [
      vehicleId,
      userId,
      crypto.randomUUID(),
      softDeleteVehicle ? 'Gone' : 'Kept',
      softDeleteVehicle ? new Date() : null,
    ],
  );
  await pool.query(
    `INSERT INTO fill_ups (
       id, user_id, mutation_id, vehicle_id, filled_at, odometer_m,
       "volume_uL", total_price_cents, currency_code, is_full
     ) VALUES ($1, $2, $3, $4, now(), 1000, 1000, 100, 'EUR', true)`,
    [crypto.randomUUID(), userId, crypto.randomUUID(), vehicleId],
  );
  const ruleId = crypto.randomUUID();
  await pool.query(
    `INSERT INTO maintenance_rules (
       id, user_id, mutation_id, vehicle_id, name, cadence_days
     ) VALUES ($1, $2, $3, $4, 'Oil', 30)`,
    [ruleId, userId, crypto.randomUUID(), vehicleId],
  );
  await pool.query(
    `INSERT INTO maintenance_events (
       id, user_id, mutation_id, vehicle_id, rule_id, performed_at, currency_code
     ) VALUES ($1, $2, $3, $4, $5, now(), 'EUR')`,
    [crypto.randomUUID(), userId, crypto.randomUUID(), vehicleId, ruleId],
  );
  await pool.query(
    `INSERT INTO settings (
       id, user_id, mutation_id, preferred_distance_unit, preferred_volume_unit,
       currency_code, timezone
     ) VALUES ($1, $1, $2, 'km', 'L', 'EUR', 'Europe/Belgrade')`,
    [userId, crypto.randomUUID()],
  );
}

async function seedPerson(label, softDeleteVehicle) {
  const googleSub = `${PREFIX}${label}-${crypto.randomUUID()}`;
  const user = await findOrCreateUser({
    googleSub,
    email: `${label}@example.test`,
  });
  const session = await pool.query(
    `INSERT INTO auth_sessions (user_id, expires_at)
     VALUES ($1, now() + interval '180 days')
     RETURNING id`,
    [user.id],
  );
  await pool.query(
    `INSERT INTO auth_refresh_tokens (session_id, token_hash, expires_at)
     VALUES ($1, $2, now() + interval '180 days')`,
    [session.rows[0].id, crypto.randomBytes(32)],
  );
  await createLoginCode({ googleSub, email: `${label}@example.test` });
  await seedProduct(user.id, softDeleteVehicle);
  return { id: user.id, googleSub, sessionId: session.rows[0].id };
}

async function wipePrefix() {
  const users = await pool.query('SELECT id FROM users WHERE google_sub LIKE $1', [`${PREFIX}%`]);
  for (const row of users.rows) {
    for (const table of PURGE_ORDER) {
      await pool.query(`DELETE FROM ${quoteIdent(table)} WHERE user_id = $1`, [row.id]);
    }
  }
  await pool.query('DELETE FROM auth_login_transactions WHERE google_sub LIKE $1', [`${PREFIX}%`]);
  await pool.query('DELETE FROM users WHERE google_sub LIKE $1', [`${PREFIX}%`]);
}

describe('purgeUser', { concurrency: 1 }, () => {
  before(async () => {
    await pool.query('GRANT DELETE ON fill_ups TO cestovni_purge');
    await wipePrefix();
  });

  after(async () => {
    await pool.query('GRANT DELETE ON fill_ups TO cestovni_purge');
    await wipePrefix();
    await pool.end();
  });

  test('PURGE_ORDER matches TABLES and public user_id tables', async () => {
    const order = new Set(PURGE_ORDER);
    const tableKeys = new Set(Object.keys(TABLES));
    const missingFromTables = [...tableKeys].filter((name) => !order.has(name));
    const extraOverTables = [...order].filter((name) => !tableKeys.has(name));
    if (missingFromTables.length) failSet('PURGE_ORDER vs TABLES', missingFromTables);
    if (extraOverTables.length) failSet('PURGE_ORDER vs TABLES extra', extraOverTables);

    const rows = await pool.query(
      `SELECT table_name
         FROM information_schema.columns
        WHERE table_schema = 'public'
          AND column_name = 'user_id'`,
    );
    const raw = new Set(rows.rows.map((row) => row.table_name));
    // auth_sessions.user_id is not a product table. Step 5 deletes users and
    // the session rows cascade. The issue SQL also returns this table.
    assert.equal(raw.has('auth_sessions'), true);
    raw.delete('auth_sessions');
    const missing = [...raw].filter((name) => !order.has(name));
    const extra = [...order].filter((name) => !raw.has(name));
    if (missing.length) failSet('PURGE_ORDER vs public user_id tables', missing);
    if (extra.length) failSet('PURGE_ORDER vs public user_id tables extra', extra);
    assert.equal(order.size, tableKeys.size);
    assert.equal(order.size, raw.size);
  });

  test('purgeUser removes one user and leaves the other', async () => {
    const a = await seedPerson('a', true);
    const b = await seedPerson('b', false);
    const beforeA = await productCounts(a.id);
    const beforeB = await productCounts(b.id);
    for (const table of PURGE_ORDER) {
      assert.equal(beforeA[table], 1, `seeded A ${table}`);
      assert.equal(beforeB[table], 1, `seeded B ${table}`);
    }

    const result = await purgeUser(a.id);
    assert.equal(result.userDeleted, true);
    assert.deepEqual(result.deleted, beforeA);

    const afterA = await productCounts(a.id);
    const afterB = await productCounts(b.id);
    for (const table of PURGE_ORDER) {
      assert.equal(afterA[table], 0, `A ${table} remains`);
      assert.equal(afterB[table], 1, `B ${table} changed`);
    }

    const aUser = await pool.query('SELECT 1 FROM users WHERE id = $1', [a.id]);
    const bUser = await pool.query('SELECT id FROM users WHERE id = $1', [b.id]);
    assert.equal(aUser.rowCount, 0);
    assert.equal(bUser.rowCount, 1);

    const aSession = await pool.query('SELECT 1 FROM auth_sessions WHERE id = $1', [a.sessionId]);
    const bSession = await pool.query('SELECT 1 FROM auth_sessions WHERE user_id = $1', [b.id]);
    assert.equal(aSession.rowCount, 0);
    assert.equal(bSession.rowCount, 1);

    const aToken = await pool.query(
      'SELECT 1 FROM auth_refresh_tokens WHERE session_id = $1',
      [a.sessionId],
    );
    const bToken = await pool.query(
      `SELECT 1 FROM auth_refresh_tokens t
         JOIN auth_sessions s ON s.id = t.session_id
        WHERE s.user_id = $1`,
      [b.id],
    );
    assert.equal(aToken.rowCount, 0);
    assert.equal(bToken.rowCount, 1);

    const aLogin = await pool.query(
      'SELECT 1 FROM auth_login_transactions WHERE google_sub = $1',
      [a.googleSub],
    );
    const bLogin = await pool.query(
      'SELECT 1 FROM auth_login_transactions WHERE google_sub = $1',
      [b.googleSub],
    );
    assert.equal(aLogin.rowCount, 0);
    assert.equal(bLogin.rowCount, 1);
  });

  test('unknown user deletes nothing', async () => {
    const beforeUsers = await pool.query('SELECT count(*)::int AS n FROM users');
    const beforeProduct = {};
    for (const table of PURGE_ORDER) {
      const res = await pool.query(`SELECT count(*)::int AS n FROM ${quoteIdent(table)}`);
      beforeProduct[table] = res.rows[0].n;
    }
    const result = await purgeUser('00000000-0000-4000-8000-000000000099');
    assert.equal(result.userDeleted, false);
    assert.deepEqual(result.deleted, {});
    const afterUsers = await pool.query('SELECT count(*)::int AS n FROM users');
    assert.equal(afterUsers.rows[0].n, beforeUsers.rows[0].n);
    for (const table of PURGE_ORDER) {
      const res = await pool.query(`SELECT count(*)::int AS n FROM ${quoteIdent(table)}`);
      assert.equal(res.rows[0].n, beforeProduct[table], `${table} changed`);
    }
  });

  test('a failed third delete rolls the earlier deletes back', async () => {
    const a = await seedPerson('rollback', true);
    await pool.query('REVOKE DELETE ON fill_ups FROM cestovni_purge');
    try {
      await assert.rejects(() => purgeUser(a.id));
      const counts = await productCounts(a.id);
      assert.equal(counts.maintenance_events, 1);
      assert.equal(counts.maintenance_rules, 1);
      const user = await pool.query('SELECT 1 FROM users WHERE id = $1', [a.id]);
      assert.equal(user.rowCount, 1);
    } finally {
      await pool.query('GRANT DELETE ON fill_ups TO cestovni_purge');
    }
  });
});
