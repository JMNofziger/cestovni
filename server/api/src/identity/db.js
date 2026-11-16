'use strict';

const { pool } = require('../db');

// Identity DML runs as cestovni_auth. No app.user_id: these tables have no RLS.
async function withAuthRole(fn) {
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
    await client.query('SET LOCAL ROLE cestovni_auth');
    await client.query('SET LOCAL search_path = public');
    const who = await client.query('SELECT current_user AS u');
    if (who.rows[0].u !== 'cestovni_auth') {
      throw new Error(`refusing to run as ${who.rows[0].u}`);
    }
    const result = await fn(client);
    if (open) {
      await client.query('COMMIT');
      open = false;
    }
    finish();
    return result;
  } catch (err) {
    if (open) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        // A callback may COMMIT (refresh reuse) and then throw. ROLLBACK
        // with no transaction is a no-op warning; anything else is fatal.
        const message = String(rollbackErr && rollbackErr.message ? rollbackErr.message : '');
        if (!/no transaction in progress/i.test(message)) {
          finish(rollbackErr);
          throw err;
        }
      }
      open = false;
    }
    finish();
    throw err;
  }
}

// Both role switches must succeed. RESET ROLE between them: neither role
// can SET ROLE to the other.
async function checkIdentityReady() {
  const client = await pool.connect();
  let open = false;
  try {
    await client.query('BEGIN');
    open = true;
    await client.query('SET LOCAL ROLE cestovni_auth');
    const auth = await client.query('SELECT current_user AS u');
    if (auth.rows[0].u !== 'cestovni_auth') {
      throw new Error('cestovni_auth role switch failed');
    }
    await client.query('RESET ROLE');
    await client.query('SET LOCAL ROLE cestovni_purge');
    const purge = await client.query('SELECT current_user AS u');
    if (purge.rows[0].u !== 'cestovni_purge') {
      throw new Error('cestovni_purge role switch failed');
    }
    await client.query('COMMIT');
    open = false;
  } catch (err) {
    if (open) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {
        // The original error is the one that matters.
      }
    }
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { withAuthRole, checkIdentityReady };
