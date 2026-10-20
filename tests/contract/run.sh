#!/usr/bin/env bash
# Run the CES-43 contract suite against a running API.
#
#   API_BASE_URL=http://127.0.0.1:8080 JWT_SECRET=dev ./tests/contract/run.sh
#
# Provisions two simulated users (JWT sub claims) and exports TOKEN_A / TOKEN_B.
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

USER_A="${USER_A:-11111111-1111-4111-8111-111111111111}"
USER_B="${USER_B:-22222222-2222-4222-8222-222222222222}"
export USER_A USER_B API_BASE_URL JWT_SECRET

TOKEN_A="$(
  node -e 'const jwt=require(process.argv[1]); process.stdout.write(jwt.sign({sub:process.argv[2]}, process.argv[3], {algorithm:"HS256", expiresIn:"1h"}));' \
    "$ROOT/server/api/node_modules/jsonwebtoken" "$USER_A" "$JWT_SECRET"
)"
TOKEN_B="$(
  node -e 'const jwt=require(process.argv[1]); process.stdout.write(jwt.sign({sub:process.argv[2]}, process.argv[3], {algorithm:"HS256", expiresIn:"1h"}));' \
    "$ROOT/server/api/node_modules/jsonwebtoken" "$USER_B" "$JWT_SECRET"
)"
export TOKEN_A TOKEN_B

echo "Test users (JWT sub):"
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
