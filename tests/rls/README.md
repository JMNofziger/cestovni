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
| Deny cross-user delete | `DELETE` as different user | Rejected. `cestovni_app` has no `DELETE` grant (v1 soft-delete is an `UPDATE` of `deleted_at`), so the statement raises `insufficient_privilege` |
| Insert WITH CHECK (valid) | `INSERT` with correct `user_id` | Succeeds |
| Insert WITH CHECK (invalid) | `INSERT` with wrong `user_id` | Rejected by policy |
| Role escalation check | `SELECT/UPDATE` as non-privileged role | Cannot bypass policy |

For shared/reference tables, test read-only vs no-access behavior explicitly.

## File conventions

- One file per table: `test_<table_name>_rls.sql` (or `.py`/`.ts` depending on chosen test runner).
- Tests use two simulated users (`SET LOCAL app.user_id` to a UUID). They run as `cestovni_app`, not as per-user database roles. `auth_user_id()` reads that GUC (JWT wiring is CES-43).
- Tests run against a clean DB with `db/migrations/0001_init.sql` applied. Each file rolls back its rows.

## Running locally

```bash
createdb cestovni_rls
DATABASE_URL=postgresql:///cestovni_rls ./tests/rls/run.sh
```

Postgres 15+ and `psql`. The DSN user must be able to `CREATE ROLE` (superuser on a fresh database). Drop the database before a second run. No Docker Compose file in this repo.

## CI integration

[`.github/workflows/rls-regression.yml`](../../.github/workflows/rls-regression.yml) runs `tests/rls/run.sh` against a Postgres 15 service container. [`ci/rls-regression.yml`](../../ci/rls-regression.yml) mirrors those steps.
