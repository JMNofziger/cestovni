#!/usr/bin/env bash
# Run the CES-43 contract suite against a running API.
#
#   API_BASE_URL=http://127.0.0.1:8080 \
#   JWT_SECRET=test-secret-ces-43-contract-suite-0123 \
#   AUTH_ISSUER_URL=http://127.0.0.1:8080 \
#   AUTH_AUDIENCE=cestovni \
#   ./tests/contract/run.sh
#
# Start server/api/test-support/contract-server.js, not src/server.js.
# That process also needs DATABASE_URL, AUTH_ISSUER_URL, and GOOGLE_CLIENT_ID.
# It does not need GOOGLE_CLIENT_SECRET. JWT_SECRET must be at least 32 characters.
# npm start is not used here.
#
# Signs in contract-user-a and contract-user-b through POST /auth/google and
# exports USER_A, USER_B, TOKEN_A, and TOKEN_B. AUTH_ISSUER_URL must match the
# server. AUTH_AUDIENCE defaults to cestovni when unset.
# The suite expects the server's default rate limits unless
# RATE_LIMIT_MUTATIONS_PER_MIN and RATE_LIMIT_CHANGES_PER_MIN are set in
# both the server process and this script.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "FAIL: API_BASE_URL is required" >&2
  exit 2
fi
if [[ -z "${JWT_SECRET:-}" ]]; then
  echo "FAIL: JWT_SECRET is required" >&2
  exit 2
fi
if [[ -z "${AUTH_ISSUER_URL:-}" ]]; then
  echo "FAIL: AUTH_ISSUER_URL is required" >&2
  exit 2
fi

export API_BASE_URL JWT_SECRET AUTH_ISSUER_URL
if [[ -n "${AUTH_AUDIENCE:-}" ]]; then
  export AUTH_AUDIENCE
fi

bootstrap="$(mktemp)"
trap 'rm -f "$bootstrap"' EXIT
node "$ROOT/tests/contract/bootstrap-users.js" > "$bootstrap"
set -a
# shellcheck disable=SC1090
source "$bootstrap"
set +a

echo "Test users (from POST /auth/google):"
echo "  user A  $USER_A"
echo "  user B  $USER_B"

failed=0
for f in "$ROOT"/tests/contract/test_*_contract.js; do
  name="$(basename "$f")"
  echo "=== $name ==="
  if node "$f"; then
    echo "PASS $name"
  else
    echo "FAIL $name"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "Contract tests: FAIL"
  exit 1
fi
echo "Contract tests: PASS"
exit 0
