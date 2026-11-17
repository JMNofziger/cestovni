'use strict';

// CES-85. Same purge as DELETE /api/v1/account, for an erasure request
// when the person cannot sign in. UUID on stdin. No other env than
// DATABASE_URL. Does not print the id.

const { pool } = require('../src/db');
const { UUID_RE } = require('../src/auth');
const { PURGE_ORDER, purgeUser } = require('../src/identity');

function readStdin() {
  return new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    process.stdin.on('error', reject);
  });
}

async function main() {
  const id = (await readStdin()).trim();
  if (!UUID_RE.test(id)) {
    console.error('invalid uuid');
    process.exitCode = 2;
    return;
  }
  const result = await purgeUser(id);
  if (!result.userDeleted) {
    console.error('no such user');
    process.exitCode = 1;
    return;
  }
  const parts = PURGE_ORDER.map((table) => `${table}=${result.deleted[table]}`);
  console.log(`purged ${parts.join(' ')}`);
}

main()
  .catch(() => {
    console.error('purge failed');
    process.exitCode = process.exitCode || 1;
  })
  .finally(() => pool.end());
