# Contract tests (API boundary)

**Linear:** CES-23 (Gate 3, Gate 6)

## Purpose

Validate that the app-owned API contract behaves identically across managed and self-host deployment modes. These tests verify request/response shapes, auth enforcement, and error handling.

## Test categories

| Category | What it validates |
|----------|-------------------|
| Auth enforcement | Valid token accepted; invalid/expired token rejected; anonymous denied |
| CRUD operations | Create, read, update, delete for each entity via contract endpoints |
| Ownership isolation | User A cannot access User B's resources through the API |
| Error shapes | Consistent error response format across endpoints |
| Parity | Same test suite passes against managed and self-host targets |

## File conventions

- One file per entity or concern: `test_<entity>_contract.{ext}`.
- Tests target the API contract URL (configurable via `API_BASE_URL` env var).
- Auth tokens are provisioned per test run (test user JWTs).

## Running locally

```bash
# Placeholder — update when API framework and test runner are selected
export API_BASE_URL=http://localhost:8080
./run-contract-tests.sh
```

## CI integration

See `ci/promotion-gates.yml` for the workflow that runs these tests against both deployment targets.
