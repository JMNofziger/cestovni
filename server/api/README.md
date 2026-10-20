# Cestovni API

App-owned sync API for [CES-43](https://linear.app/personal-interests-llc/issue/CES-43). Node.js `http` plus `pg` and `jsonwebtoken`. No Express, ORM, or provider SDK.

Normative contract: [`docs/specs/sync-protocol.md`](../../docs/specs/sync-protocol.md) and [ADR 001](../../docs/specs/adr/001-backend-api-boundary.md). Schema and RLS: [`db/migrations/0001_init.sql`](../../db/migrations/0001_init.sql).

The in-memory dev stub at [`server/dev-sync-stub/`](../dev-sync-stub/) is a separate zero-dep tool. This process does not replace it.

## Endpoints

| Method | Path | Auth |
| ------ | ---- | ---- |
| `GET` | `/healthz` | none — `{ok: true}` after a Postgres round-trip |
| `POST` | `/api/v1/mutations` | bearer JWT |
| `GET` | `/api/v1/changes?table=&since=&limit=` | bearer JWT |
| `GET` | `/api/v1/restore/manifest` | bearer JWT |

Errors use `{error: {code, message, retriable}}`.

## Auth and RLS

`JWT_SECRET` verifies HS256 bearer tokens. `sub` must be the user UUID. Other algorithms are rejected.

`cestovni_app` is `NOLOGIN`, so the DSN user cannot be that role. Every product transaction does:

1. `BEGIN`
2. `SET LOCAL ROLE cestovni_app`
3. `SET LOCAL search_path = public`
4. `set_config('app.user_id', <sub>, true)`

`auth_user_id()` then feeds the CES-42 policies. The DSN role must be allowed to `SET ROLE cestovni_app`: a superuser, or `GRANT cestovni_app TO <dsn_role>`. Startup and `/healthz` both refuse to serve if `current_user` is not `cestovni_app` after that switch.

The server writes `user_id` from `auth_user_id()`. A `user_id` field in a mutation payload is ignored. `row_version` and `updated_at` come from `cestovni_touch_row()`.

## Idempotency

Dedup is a lookup of `mutation_id` on the target table, inside an advisory transaction lock on `table:row_id`. A retry of the row's **current** `mutation_id` returns `status: "duplicate"` and the stored `row_version`. A later write replaces `mutation_id`, so a retry of an older key is not remembered and is treated as a new mutation.

Mutations in one request share one transaction. Each mutation has a savepoint, so a rejected row does not roll back the ones that applied. Unknown `table` is a per-mutation `rejected` result (HTTP 200). HTTP 400 is malformed JSON, a missing `mutations` array, or a bad `GET /changes` query.

## Limits

| Limit | Default | Env |
| ----- | ------- | --- |
| Mutations per user per 60s | 60 | `RATE_LIMIT_MUTATIONS_PER_MIN` |
| Changes + manifest requests per user per 60s | 120 | `RATE_LIMIT_CHANGES_PER_MIN` |
| Mutations per request | 100 | — (413 `batch_too_large`) |
| Body | 1 MiB | — (413 `payload_too_large`) |
| Changes `limit` | 200, clamp 500 | response header `X-Limit-Clamped: true` |

The limiter is a fixed window in this process. A request that does not fit is HTTP 429 with `Retry-After` (seconds) and does not consume quota. It is not shared across processes.

`CORS_ORIGINS` defaults to `*`. Set a comma-separated allow-list to pin origins.

## Run locally

Postgres 15+ with [`0001_init.sql`](../../db/migrations/0001_init.sql) applied to an empty database. Apply it once; it is not idempotent (roles are created only if missing, tables are not).

```bash
cd server/api
npm ci
DATABASE_URL=postgresql://postgres@127.0.0.1:5432/cestovni \
  JWT_SECRET=dev-secret \
  PORT=8080 \
  npm start
```

`PORT` defaults to `8080`. `HOST` defaults to `0.0.0.0`.

Contract suite (mints user A and user B JWTs from `JWT_SECRET`):

```bash
API_BASE_URL=http://127.0.0.1:8080 JWT_SECRET=dev-secret ./tests/contract/run.sh
```

If you override the rate-limit env vars, set the same values on the server and on `run.sh`. `RATE_LIMIT_MUTATIONS_PER_MIN` must stay below 100 or the burst test hits the batch cap first.
