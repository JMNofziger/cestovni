#!/usr/bin/env bash
# CES-80 migration runner. Four cases, each on a throwaway database.
#
#   DATABASE_URL='postgresql:///postgres?host=/var/run/postgresql' ./tests/migrate/run.sh
#
# Case 4's bad file starts with CREATE TABLE so a runner that committed the
# first statement would leave migrate_bad_should_not_exist. Then SELECT 1
# and a syntax error, as the issue requires.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATE="$ROOT/server/api/scripts/migrate.js"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "FAIL: DATABASE_URL is required (superuser DSN)" >&2
  exit 2
fi
if ! command -v psql >/dev/null 2>&1; then
  echo "FAIL: psql is required" >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  echo "FAIL: node is required" >&2
  exit 2
fi

suffix="$$"
dbs=()
dirs=()

cleanup() {
  local db dir
  if ((${#dbs[@]})); then
    for db in "${dbs[@]}"; do
      psql "$DATABASE_URL" -X -c "DROP DATABASE IF EXISTS ${db} WITH (FORCE);" >/dev/null 2>&1 || true
    done
  fi
  if ((${#dirs[@]})); then
    for dir in "${dirs[@]}"; do
      rm -rf "$dir"
    done
  fi
}
trap cleanup EXIT

db_url() {
  node -e 'const u = new URL(process.argv[1]); u.pathname = "/" + process.argv[2]; process.stdout.write(u.toString());' \
    "$DATABASE_URL" "$1"
}

create_db() {
  local name="$1"
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${name};" >/dev/null
  dbs+=("$name")
}

versions() {
  psql "$1" -qAtX -v ON_ERROR_STOP=1 -c "SELECT version FROM schema_migrations ORDER BY version"
}

applied_at_stamp() {
  psql "$1" -qAtX -v ON_ERROR_STOP=1 -c \
    "SELECT version || ' ' || applied_at FROM schema_migrations ORDER BY version"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL $label" >&2
    printf 'expected:\n%s\n' "$expected" >&2
    printf 'actual:\n%s\n' "$actual" >&2
    exit 1
  fi
}

echo "=== case 1: fresh database ==="
fresh="cestovni_mig_fresh_${suffix}"
create_db "$fresh"
fresh_url="$(db_url "$fresh")"
fresh_out="$(DATABASE_URL="$fresh_url" node "$MIGRATE")"
assert_eq "case 1 stdout" $'applied 0001_init.sql\napplied 0002_identity.sql\nmigrate: 2 applied, 0 already recorded' "$fresh_out"
assert_eq "case 1 versions" $'0001\n0002' "$(versions "$fresh_url")"
echo "PASS case 1"

echo "=== case 2: second run is a no-op ==="
before="$(applied_at_stamp "$fresh_url")"
second_out="$(DATABASE_URL="$fresh_url" node "$MIGRATE")"
after="$(applied_at_stamp "$fresh_url")"
assert_eq "case 2 stdout" "migrate: 0 applied, 2 already recorded" "$second_out"
assert_eq "case 2 applied_at" "$before" "$after"
echo "PASS case 2"

echo "=== case 3: baseline 0001 then apply 0002 ==="
base="cestovni_mig_base_${suffix}"
create_db "$base"
base_url="$(db_url "$base")"
psql "$base_url" -qX -v ON_ERROR_STOP=1 -f "$ROOT/db/migrations/0001_init.sql" >/dev/null
base_out="$(DATABASE_URL="$base_url" node "$MIGRATE" --baseline 0001)"
assert_eq "case 3 stdout" $'baselined 0001\napplied 0002_identity.sql\nmigrate: 1 applied, 1 already recorded' "$base_out"
assert_eq "case 3 versions" $'0001\n0002' "$(versions "$base_url")"
echo "PASS case 3"

echo "=== case 4: failing migration rolls back ==="
bad="cestovni_mig_bad_${suffix}"
create_db "$bad"
bad_url="$(db_url "$bad")"
bad_dir="$(mktemp -d)"
dirs+=("$bad_dir")
cp "$ROOT/db/migrations/0001_init.sql" "$bad_dir/0001_init.sql"
cat >"$bad_dir/0002_bad.sql" <<'EOF'
CREATE TABLE migrate_bad_should_not_exist (id integer);
SELECT 1;
MIGRATE_BAD_SYNTAX;
EOF
bad_stdout="$(mktemp)"
bad_stderr="$(mktemp)"
set +e
DATABASE_URL="$bad_url" MIGRATIONS_DIR="$bad_dir" node "$MIGRATE" >"$bad_stdout" 2>"$bad_stderr"
bad_code=$?
set -e
if [[ "$bad_code" -ne 1 ]]; then
  echo "FAIL case 4 exit code $bad_code" >&2
  echo "--- stdout ---" >&2
  cat "$bad_stdout" >&2
  echo "--- stderr ---" >&2
  cat "$bad_stderr" >&2
  rm -f "$bad_stdout" "$bad_stderr"
  exit 1
fi
if ! grep -q '0002_bad.sql' "$bad_stderr"; then
  echo "FAIL case 4 stderr missing file name" >&2
  cat "$bad_stderr" >&2
  rm -f "$bad_stdout" "$bad_stderr"
  exit 1
fi
if ! grep -q 'MIGRATE_BAD_SYNTAX' "$bad_stderr"; then
  echo "FAIL case 4 stderr missing failing statement" >&2
  cat "$bad_stderr" >&2
  rm -f "$bad_stdout" "$bad_stderr"
  exit 1
fi
rm -f "$bad_stdout" "$bad_stderr"
assert_eq "case 4 versions" "0001" "$(versions "$bad_url")"
persisted="$(psql "$bad_url" -qAtX -v ON_ERROR_STOP=1 -c "SELECT to_regclass('public.migrate_bad_should_not_exist') IS NOT NULL")"
assert_eq "case 4 first statement persisted" "f" "$persisted"
echo "PASS case 4"

echo "Migration runner tests: PASS"
exit 0
