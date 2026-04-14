# Least-privilege role validation tests

**Linear:** CES-23 (Gate 5)

## Purpose

Verify that Postgres roles are configured with minimum necessary privileges and that role boundaries cannot be bypassed during normal operation.

## Role model

| Role | Purpose | Allowed | Denied |
|------|---------|---------|--------|
| `cestovni_app` (runtime) | Normal API operations | SELECT, INSERT, UPDATE, DELETE on product tables via RLS | CREATE, ALTER, DROP, GRANT, TRUNCATE; access to migration-only tables |
| `cestovni_migrate` (migration) | Schema changes during deploy | DDL on all product tables; runs migrations | Should not be used during normal operation; time-bound to migration window |
| `cestovni_admin` (break-glass) | Emergency access only | Full superuser-equivalent | Must not be used without incident record; credentials rotated after use |
| `anon` (anonymous) | Unauthenticated requests | None (deny by default) | All data access |

## Test cases

| # | Check | How to verify |
|---|-------|---------------|
| 1 | Runtime role cannot CREATE/ALTER/DROP tables | Attempt DDL as `cestovni_app`; expect permission denied |
| 2 | Runtime role cannot GRANT privileges | Attempt GRANT as `cestovni_app`; expect permission denied |
| 3 | Runtime role cannot TRUNCATE tables | Attempt TRUNCATE as `cestovni_app`; expect permission denied |
| 4 | Runtime role can only access data through RLS | Verify no BYPASSRLS attribute on `cestovni_app` |
| 5 | Migration role can run DDL | Attempt CREATE TABLE as `cestovni_migrate`; expect success |
| 6 | Anonymous role has no data access | Attempt SELECT as `anon` on any product table; expect denied |
| 7 | Admin credentials are not in `.env.example` | Grep `.env.example` for admin password; expect absent |

## File conventions

- `validate_role_separation.sql` — SQL checks for role attributes and privilege grants.
- Extend with programmatic tests when test runner is selected.

## CI integration

Runs as part of `ci/promotion-gates.yml` migration dry-run job (role checks after migration apply).
