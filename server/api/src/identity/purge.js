'use strict';

const { pool } = require('../db');
const { quoteIdent } = require('../schema');

// Child before parent. Product foreign keys do not cascade.
const PURGE_ORDER = [
  'maintenance_events',
  'maintenance_rules',
  'fill_ups',
  'vehicles',
  'settings',
];

// One connection, one transaction. Sessions and refresh tokens cascade
// from the users delete. Login transactions have no user_id, so they go
// by google_sub. Never log the id next to row data.
async function purgeUser(userId) {
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
    await client.query('SET LOCAL search_path = public');
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [
      `user:${userId}`,
    ]);

    await client.query('SET LOCAL ROLE cestovni_auth');
    const user = await client.query('SELECT google_sub FROM users WHERE id = $1', [userId]);
    if (user.rowCount !== 1) {
      await client.query('ROLLBACK');
      open = false;
      finish();
      return { userDeleted: false, deleted: {} };
    }
    const googleSub = user.rows[0].google_sub;

    await client.query('RESET ROLE');
    await client.query('SET LOCAL ROLE cestovni_purge');
    await client.query("SELECT set_config('app.user_id', $1, true)", [userId]);
    const deleted = {};
    for (const table of PURGE_ORDER) {
      const result = await client.query(
        `DELETE FROM ${quoteIdent(table)} WHERE user_id = $1`,
        [userId],
      );
      deleted[table] = result.rowCount;
    }

    await client.query('RESET ROLE');
    await client.query('SET LOCAL ROLE cestovni_auth');
    await client.query('DELETE FROM auth_login_transactions WHERE google_sub = $1', [googleSub]);
    await client.query('DELETE FROM users WHERE id = $1', [userId]);
    await client.query('COMMIT');
    open = false;
    finish();
    return { userDeleted: true, deleted };
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

module.exports = { PURGE_ORDER, purgeUser };
