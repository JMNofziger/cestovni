# Cursor execution prompt — CES-43 Server API + auth

> **Status: NOT STARTED.**
> **Linear:** [CES-43](https://linear.app/personal-interests-llc/issue/CES-43) — Backlog.
> **Blocked by:** CES-42 (Server Postgres + RLS must merge first).
> **Blocks:** CES-44 (Client outbox expansion), and transitively CES-45.
> This is the second M3 ticket. Do not start CES-44 until this merges.

**Branch:** cut from **`main`** (after CES-42 merges)
**Spec (normative):** [`docs/specs/sync-protocol.md`](../../specs/sync-protocol.md) + [`docs/specs/adr/001-backend-api-boundary.md`](../../specs/adr/001-backend-api-boundary.md)
**Also read:** [`docs/specs/adr/002-backup-sync-layer.md`](../../specs/adr/002-backup-sync-layer.md) · [`docs/specs/data-model.md`](../../specs/data-model.md) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-42** Server Postgres + RLS on `main` |
| M0–M2 | **Closed.** Client DB at schema v5. Export + import shipped. |
| M3 | **CES-42 done.** DB + RLS + roles + regression suite merged. |
| Dev sync stub | `server/dev-sync-stub/` — in-memory Node stub, all 5 tables, trivial bearer auth. Leave it untouched; it stays as a zero-dep local dev tool. |
| RLS CI | `.github/workflows/rls-regression.yml` — live, running `tests/rls/run.sh` against Postgres 15. |
| Contract tests | `tests/contract/README.md` — placeholder scaffold only. This ticket fills it in. |
| Client sync | `client/lib/sync/` — gate-slice flush worker + `SyncClient` targeting the dev stub. Fill-ups only. CES-44 will expand this; do not change client code here. |

**Git start:** `git fetch origin && git checkout -b cursor/ces-43-<suffix> origin/main`

---

## Goal

Implement the **app-owned HTTPS API** per ADR 001 + `sync-protocol.md`: three endpoints, JWT-based auth, idempotent mutations, rate limiting, and a runnable contract test suite.

Concretely:

1. A Node.js (or equivalent lean runtime) API server in `server/api/` that connects to the CES-42 Postgres
2. `POST /api/v1/mutations` — batch upload, idempotent by `mutation_id`, assigns `row_version` from `cestovni_row_version_seq`
3. `GET /api/v1/changes?table=…&since=…&limit=…` — cursor-paginated catch-up stream
4. `GET /api/v1/restore/manifest` — per-table row counts + max `row_version` for restore UX
5. JWT auth middleware extracting `user_id` from the token and setting `SET LOCAL app.user_id`
6. Contract tests in `tests/contract/` exercising both deployment targets

---

## Locked decisions (do not re-litigate)

### 1. Node.js + zero-framework server

Use Node.js with the built-in `http` module (or a minimal routing layer like `express` if routing becomes unwieldy — but prefer zero deps to match the dev stub pattern). The server MUST NOT depend on a provider SDK, an ORM, or a managed-backend runtime. It connects to Postgres via `pg` (node-postgres).

### 2. Auth: JWT with `app.user_id` session variable

The server validates a bearer JWT, extracts the `sub` claim as the user UUID, and runs `SET LOCAL app.user_id = '<uuid>'` on every request's Postgres transaction. This flows through `auth_user_id()` into RLS policies (CES-42). For v1, the JWT signing key is configured via `JWT_SECRET` env var (symmetric HS256). Real OIDC / asymmetric keys are a future concern — the contract is: the token `sub` claim is the user identity.

Token validation:
- Missing or malformed `Authorization: Bearer <token>` → HTTP 401, `{error: {code: "unauthenticated", message: "…", retriable: false}}`
- Expired token → HTTP 401, same shape
- Valid token → extract `sub` as `user_id`; proceed

### 3. Endpoint contracts per sync-protocol.md

**`POST /api/v1/mutations`:**
- Accepts `{mutations: [...]}` (max 100 per batch, max 1 MiB body)
- Each mutation: `{mutation_id, table, op, row_id, payload}`
- `op` ∈ `{insert, update, soft_delete}`
- Server assigns `user_id` from the JWT (never trust client `user_id` in payload)
- Server assigns `row_version` from `cestovni_row_version_seq` and `updated_at = now()`
- Idempotent: same `mutation_id` → return original `row_version` with `status: "duplicate"`
- Per-mutation results: `{mutation_id, row_id, row_version, server_updated_at, status}` where status ∈ `{applied, duplicate, rejected}`
- Rejected mutations carry `{error: {code, message, retriable}}`
- Partial rejection: non-rejected mutations still apply; rejected ones do not roll back the rest
- All mutations in one request execute in a single Postgres transaction
- Batch > 100 → HTTP 413 `batch_too_large`
- Body > 1 MiB → HTTP 413 `payload_too_large`

**`GET /api/v1/changes?table=…&since=…&limit=…`:**
- Returns rows with `row_version > since`, ordered ascending, user-scoped (RLS enforces)
- `limit` clamped to 500; default 200
- Response: `{table, rows: [...], next_since, has_more}`
- Soft-deleted rows included (so clients reconcile tombstones)

**`GET /api/v1/restore/manifest`:**
- Returns per-table `{table, row_count, max_row_version}` for the authenticated user
- Tables: `vehicles`, `fill_ups`, `maintenance_rules`, `maintenance_events`, `settings`

### 4. HTTP status map per sync-protocol.md

| Status | Meaning | `retriable` |
|--------|---------|-------------|
| 200 | Success | — |
| 400 | Bad request (malformed JSON, missing fields, unknown table) | `false` |
| 401 | Token missing, invalid, or expired | — (client re-auths) |
| 403 | RLS rejected (indicates server bug) | `false` |
| 413 | Batch too large or body too large | `false` (for the specific mutation/batch) |
| 429 | Rate limited — include `Retry-After` header | `true` |
| 5xx | Server error | `true` |

Error shape: `{error: {code: "string", message: "string", retriable: boolean}}`

### 5. Rate limiting (429)

Implement a simple in-memory per-user rate limiter. Default: 60 mutations/min, 120 changes requests/min. Configurable via env vars (`RATE_LIMIT_MUTATIONS_PER_MIN`, `RATE_LIMIT_CHANGES_PER_MIN`). When exceeded, return 429 with `Retry-After: <seconds>` header. The rate limiter does NOT need to be distributed (single-process is fine for v1).

### 6. CORS

Permissive CORS for local dev (match dev stub pattern). For production, pin origins via `CORS_ORIGINS` env var. Default in dev: `*`.

### 7. Connection to CES-42 Postgres

The server connects using `DATABASE_URL` env var (standard Postgres DSN). On each authenticated request, the server:
1. Gets a connection from the pool
2. Runs `SET LOCAL app.user_id = '<jwt-sub>'` inside a transaction
3. Executes the endpoint logic
4. Commits (or rolls back on error)

The server connects AS `cestovni_app` role (the runtime role from CES-42), never as `cestovni_migrate` or superuser.

---

## Scope (in)

1. **`server/api/server.js`** (or `server/api/src/` if multiple files) — the API server. Dependencies: `pg` (node-postgres), `jsonwebtoken` (JWT verification). No Express unless routing justifies it.
2. **`server/api/package.json`** — minimal, with `pg` and `jsonwebtoken` and a `start` script.
3. **`POST /api/v1/mutations`** — full implementation per locked decision 3, including idempotent dedup via `mutation_id` column lookup, `row_version` assignment from the shared sequence, and RLS-scoped writes.
4. **`GET /api/v1/changes`** — cursor-paginated, RLS-scoped reads with limit clamping.
5. **`GET /api/v1/restore/manifest`** — per-table aggregates, user-scoped.
6. **`GET /healthz`** — unauthenticated health check (returns `{ok: true}`).
7. **Rate limiter** — per-user, in-memory, per locked decision 5.
8. **`tests/contract/`** — runnable contract test suite. One file per concern:
   - `test_auth_contract.js` — valid JWT accepted, invalid rejected, expired rejected, missing rejected, anonymous denied
   - `test_mutations_contract.js` — insert → applied, idempotent retry → duplicate, bad table → rejected, batch cap → 413, cross-user isolation (user A's mutation doesn't appear in user B's changes)
   - `test_changes_contract.js` — cursor pagination, limit clamping, soft-deleted rows included, cross-user isolation
   - `test_restore_contract.js` — manifest shape, counts match, cross-user isolation
   - `test_rate_limit_contract.js` — burst past limit → 429 + Retry-After header
9. **`tests/contract/run.sh`** — takes `$API_BASE_URL` + `$JWT_SECRET`, provisions two test JWTs (user A, user B), runs the suite, reports PASS/FAIL.
10. **`.github/workflows/contract-tests.yml`** — CI workflow: Postgres 15 service container, apply `db/migrations/0001_init.sql`, start the API server, run contract tests.
11. **`server/api/README.md`** — setup: env vars, how to run locally, how to run against a remote Postgres.
12. **`tests/contract/README.md`** — update from placeholder to real instructions.

## Scope (out)

- **Client code changes** (CES-44 wires client to real API)
- **Dev sync stub changes** (leave `server/dev-sync-stub/` untouched)
- **OIDC / asymmetric JWT** (future — symmetric HS256 is sufficient for v1)
- **Docker Compose** for production (later infrastructure ticket)
- **RLS migration changes** (CES-42 schema is complete)
- **Telemetry / metrics emission** (CES-46)
- **429 client-side handling** (already in `SyncClient`; CES-44 expands it)
- **Portal / browser client** (gated on M3 + ADR 006)

## Constraints

- Node.js 22+ (matches CI and AGENTS.md).
- The API server runs as `cestovni_app` role — no superuser, no BYPASSRLS.
- JWT signing uses symmetric HS256 via `JWT_SECRET` env var.
- Contract tests must use two distinct test users to prove RLS isolation.
- Existing `verify-fast.yml`, `verify-full.yml`, and `rls-regression.yml` must stay green.
- `python3 ci/telemetry-gate.py` must still pass (no client changes).
- Dev sync stub (`server/dev-sync-stub/`) is untouched and continues to work independently.

## Acceptance

- [ ] API server starts and connects to CES-42 Postgres as `cestovni_app`.
- [ ] `POST /api/v1/mutations`: insert → `applied` with server-assigned `row_version`; same `mutation_id` → `duplicate` with same `row_version`; bad table → `rejected`; batch > 100 → 413.
- [ ] `GET /api/v1/changes`: returns rows `WHERE row_version > since`, user-scoped, limit-clamped to 500, soft-deleted included, `has_more` correct.
- [ ] `GET /api/v1/restore/manifest`: per-table counts and max `row_version`, user-scoped.
- [ ] Auth: missing token → 401, invalid token → 401, expired token → 401, valid token → proceeds.
- [ ] Cross-user isolation: user A's data invisible to user B across all three endpoints.
- [ ] Rate limiting: burst past threshold → 429 with `Retry-After`.
- [ ] Contract tests in `tests/contract/` cover all of the above and pass in CI.
- [ ] `server/api/README.md` documents env vars and local setup.
- [ ] `delivery-plan-v1.md` CES-43 row → 🟩.
- [ ] Linear CES-43 Done + closeout comment.

## Status report (required)

1. Server framework choice and file layout
2. JWT validation approach (library, claim extraction, `SET LOCAL` flow)
3. `mutation_id` idempotency implementation (lookup strategy, dedup logic)
4. Rate limiter design (window type, storage, configurability)
5. Contract test coverage summary (categories × test cases)
6. CI workflow integration (how the API server + Postgres spin up)
7. Known limits (e.g. symmetric JWT only, single-process rate limiter, no OIDC)
8. PR URL + Linear CES-43 state

Tag: `CES-43 — Server API + auth`.
