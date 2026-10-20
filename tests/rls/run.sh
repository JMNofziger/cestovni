#!/usr/bin/env bash
# Apply db/migrations/0001_init.sql and run tests/rls/test_*_rls.sql.
#
# Requires a fresh Postgres 15+ database and a superuser connection
# (the migration creates roles). Not idempotent — drop the database
# before a second run.
#
#   createdb cestovni_rls
#   DATABASE_URL=postgresql:///cestovni_rls ./tests/rls/run.sh
#
# Simulated users (no users table; identity is the app.user_id GUC):
#   user A  11111111-1111-4111-8111-111111111111
#   user B  22222222-2222-4222-8222-222222222222

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "FAIL: DATABASE_URL is required (superuser DSN, empty database)" >&2
  exit 2
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "FAIL: psql is required" >&2
  exit 2
fi

USER_A="11111111-1111-4111-8111-111111111111"
USER_B="22222222-2222-4222-8222-222222222222"

echo "Applying db/migrations/0001_init.sql"
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$ROOT/db/migrations/0001_init.sql" >/dev/null

echo "Creating simulated test users (session GUC app.user_id)"
echo "  user A  $USER_A"
echo "  user B  $USER_B"
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -c \
  "BEGIN;
   SELECT set_config('app.user_id', '$USER_A', true);
   DO \$\$
   BEGIN
     IF auth_user_id()::text <> '$USER_A' THEN
       RAISE EXCEPTION 'auth_user_id() did not echo user A';
     END IF;
   END
   \$\$;
   SELECT set_config('app.user_id', '$USER_B', true);
   DO \$\$
   BEGIN
     IF auth_user_id()::text <> '$USER_B' THEN
       RAISE EXCEPTION 'auth_user_id() did not echo user B';
     END IF;
   END
   \$\$;
   ROLLBACK;" >/dev/null

failed=0
for f in "$ROOT"/tests/rls/test_*_rls.sql; do
  name="$(basename "$f")"
  echo "=== $name ==="
  if psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f "$f"; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "RLS regression: FAIL"
  exit 1
fi

echo "RLS regression: PASS"
exit 0
