# RLS / Authorization regression tests

**Linear:** CES-23 (Gate 4)

## Purpose

Validate that Postgres RLS policies enforce ownership and tenancy rules correctly. These tests run on every migration PR and pre-release staging promotion.

## Test matrix (per user-scoped table)

Each table with RLS policies must have tests covering:

| Case | Query | Expected |
|------|-------|----------|
| Allow own read | `SELECT` as owner | Returns owner's rows only |
| Deny cross-user read | `SELECT` as different user | Returns empty / 0 rows |
| Allow own update | `UPDATE` as owner | Succeeds for owner's rows |
| Deny cross-user update | `UPDATE` as different user | 0 rows affected |
| Deny cross-user delete | `DELETE` as different user | 0 rows affected |
| Insert WITH CHECK (valid) | `INSERT` with correct `user_id` | Succeeds |
| Insert WITH CHECK (invalid) | `INSERT` with wrong `user_id` | Rejected by policy |
| Role escalation check | `SELECT/UPDATE` as non-privileged role | Cannot bypass policy |

For shared/reference tables, test read-only vs no-access behavior explicitly.

## File conventions

- One file per table: `test_<table_name>_rls.sql` (or `.py`/`.ts` depending on chosen test runner).
- Tests use two distinct test users with separate JWTs/roles.
- Tests run against a clean DB with migrations applied and minimal seed data.

## Running locally

```bash
# Placeholder — update when test runner is selected
docker compose -f docker-compose.test.yml up -d
./run-rls-tests.sh
```

## CI integration

See `ci/rls-regression.yml` for the workflow that runs these tests.
