'use strict';

const { signUser } = require('./http');

async function main() {
  const a = await signUser('contract-user-a');
  const b = await signUser('contract-user-b');
  process.stdout.write(
    `USER_A=${a.userId}\nUSER_B=${b.userId}\nTOKEN_A=${a.token}\nTOKEN_B=${b.token}\n`
  );
}

main().catch((err) => {
  console.error(err && err.message ? err.message : 'bootstrap failed');
  process.exitCode = 1;
});
