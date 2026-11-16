'use strict';

const { withAuthRole } = require('./db');

async function findOrCreateUser({ googleSub, email }) {
  return withAuthRole(async (client) => {
    const result = await client.query(
      `INSERT INTO users (google_sub, email)
       VALUES ($1, $2)
       ON CONFLICT (google_sub) DO UPDATE
         SET email = COALESCE(EXCLUDED.email, users.email)
       RETURNING id, email`,
      [googleSub, email ?? null]
    );
    const row = result.rows[0];
    return { id: row.id, email: row.email };
  });
}

async function getUser(userId) {
  return withAuthRole(async (client) => {
    const result = await client.query(
      'SELECT id, email FROM users WHERE id = $1',
      [userId]
    );
    if (result.rowCount !== 1) return null;
    return { id: result.rows[0].id, email: result.rows[0].email };
  });
}

module.exports = { findOrCreateUser, getUser };
