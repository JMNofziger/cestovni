'use strict';

const { Pool, types } = require('pg');

// int8 → number. v1 magnitudes (meters, µL, cents, row_version) fit in
// Number.MAX_SAFE_INTEGER. bpchar → trim so CHAR(3) currency codes are 'EUR'.
types.setTypeParser(20, (value) => {
  const n = Number(value);
  if (!Number.isSafeInteger(n)) {
    throw new Error(`bigint exceeds Number.MAX_SAFE_INTEGER: ${value}`);
  }
  return n;
});
types.setTypeParser(1042, (value) => value.replace(/ +$/, ''));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  application_name: 'cestovni-api',
});

// cestovni_app is NOLOGIN. The DSN user (CI bootstrap superuser, or any
// role granted membership) must SET ROLE before product SQL. After this
// returns, current_user is cestovni_app and auth_user_id() is `userId`,
// so RLS applies. Superuser DML is refused.
async function withUser(userId, fn) {
  const client = await pool.connect();
  let open = false;
  let released = false;
  const finish = (destroyWith) => {
    if (released) return;
    released = true;
    if (destroyWith) client.release(destroyWith);
    else client.release();
  };
  try {
    await client.query('BEGIN');
    open = true;
    await client.query('SET LOCAL ROLE cestovni_app');
    await client.query('SET LOCAL search_path = public');
    await client.query("SELECT set_config('app.user_id', $1, true)", [userId]);
    const who = await client.query('SELECT current_user AS u');
    if (who.rows[0].u !== 'cestovni_app') {
      throw new Error(`refusing to run as ${who.rows[0].u}`);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    open = false;
    finish();
    return result;
  } catch (err) {
    if (open) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        finish(rollbackErr);
        throw err;
      }
    }
    finish();
    throw err;
  }
}

async function checkReady() {
  await withUser('00000000-0000-4000-8000-000000000000', async (client) => {
    const row = await client.query('SELECT auth_user_id() AS uid');
    if (row.rows[0].uid !== '00000000-0000-4000-8000-000000000000') {
      throw new Error('auth_user_id() did not echo the session user');
    }
  });
}

function iso(value) {
  if (value == null) return null;
  if (value instanceof Date) return value.toISOString();
  return new Date(value).toISOString();
}

module.exports = { pool, withUser, checkReady, iso };
