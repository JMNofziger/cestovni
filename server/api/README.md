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
| `GET` | `/api/v1/auth/google/start?client=` | none — 302 to Google |
| `GET` | `/api/v1/auth/google/callback` | none — 302 to the allowlisted app URL |
| `POST` | `/api/v1/auth/google` | none — `{id_token}` → session |
| `POST` | `/api/v1/auth/google/exchange` | none — `{code}` → session |
| `POST` | `/api/v1/auth/refresh` | none — `{refresh_token}` → session |
| `POST` | `/api/v1/auth/logout` | none — `{refresh_token}` → 204 |

Errors use `{error: {code, message, retriable}}`.

## Auth and RLS

[ADR 007](../../docs/specs/adr/007-identity-provider.md) and [`docs/specs/identity-provider.md`](../../docs/specs/identity-provider.md): Google is the only sign-in door. `npm start` exchanges the authorization code and checks the ID token. The access token is HS256. `sub` is `users.id`, which this API allocates. `google_sub` is stored and is never that id.

`JWT_SECRET` must be at least 32 characters. It signs access tokens and verifies bearer tokens on sync routes. A sync token must be HS256 with this API's `iss` and `aud`, a UUID `sub`, a UUID `sid`, and an active session. Other algorithms are rejected. `GET /healthz` and `/api/v1/auth/*` stay public. Logout takes effect on the next sync call. Contract tests sign in through `POST /auth/google` on the contract server. `JWT_SECRET` is used only for the negative token cases.

`npm start` refuses to boot unless `JWT_SECRET` is at least 32 characters and `AUTH_ISSUER_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `DATABASE_URL` are set. `AUTH_PORTAL_REDIRECT`, when set, must be an absolute http(s) URL. The contract suite does not use `npm start`. It starts `test-support/contract-server.js`, which injects a fake verifier and does not need `GOOGLE_CLIENT_SECRET`.

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
| `POST /auth/google` and `/exchange`, shared, per IP per 15 min | 20 | — |
| `GET /auth/google/start` per IP per 15 min | 30 | — |
| `POST /auth/refresh` per IP per 60 min | 60 | — |
| Mutations per request | 100 | — (413 `batch_too_large`) |
| Sync body | 1 MiB | — (413 `payload_too_large`) |
| Auth body | 1 KiB | — (413 `payload_too_large`) |
| Changes `limit` | 200, clamp 500 | response header `X-Limit-Clamped: true` |

The limiter is a fixed window in this process. A request that does not fit is HTTP 429 with `Retry-After` (seconds) and does not consume quota. It is not shared across processes. Auth limits use the socket address, or, when `TRUST_PROXY_HOPS` is greater than 0, the `X-Forwarded-For` entry that many places from the right. The default is 0. Deploy with one instance ([CES-94](https://linear.app/personal-interests-llc/issue/CES-94)).

`CORS_ORIGINS` defaults to `*`. Set a comma-separated allow-list to pin origins.

## Run locally

Postgres 15+. From `server/api`, `npm run migrate` applies `db/migrations` with a superuser `DATABASE_URL`. A second run changes nothing. The API does not migrate on startup.

```bash
cd server/api
npm ci
# TCP when the DSN user has a password (CI uses this shape).
DATABASE_URL=postgresql://cestovni_test:testpass@127.0.0.1:5432/cestovni \
  npm run migrate
DATABASE_URL=postgresql://cestovni_test:testpass@127.0.0.1:5432/cestovni \
  JWT_SECRET=dev-secret-must-be-at-least-32-chars \
  AUTH_ISSUER_URL=http://127.0.0.1:8080 \
  GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com \
  GOOGLE_CLIENT_SECRET=your-client-secret \
  PORT=8080 \
  npm start
```

A database that already had `0001_init.sql` applied with `psql` (records `0001`, then applies what is pending):

```bash
DATABASE_URL=postgresql://cestovni_test:testpass@127.0.0.1:5432/cestovni \
  npm run migrate -- --baseline 0001
```

`node-pg` does not accept a `psql`-style DSN with no host (`postgresql:///db`). Use a TCP URL, or `?host=` for the local socket. This repo's local cluster requires SCRAM on `127.0.0.1`. For peer auth over the Unix socket, run the process as the database OS user and set the host:

```bash
sudo -u postgres env \
  DATABASE_URL='postgresql:///cestovni?host=/var/run/postgresql' \
  npm run migrate
sudo -u postgres env \
  DATABASE_URL='postgresql:///cestovni?host=/var/run/postgresql' \
  JWT_SECRET=dev-secret-must-be-at-least-32-chars \
  AUTH_ISSUER_URL=http://127.0.0.1:8080 \
  GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com \
  GOOGLE_CLIENT_SECRET=your-client-secret \
  PORT=8080 \
  node src/server.js
```

`PORT` defaults to `8080`. `HOST` defaults to `0.0.0.0`. A remote Postgres is the same `DATABASE_URL`; the role still has to be able to `SET ROLE cestovni_app`.

Contract suite. `run.sh` signs in two users through `POST /auth/google`. Start the contract server, not `npm start`:

```bash
DATABASE_URL=postgresql://cestovni_test:testpass@127.0.0.1:5432/cestovni \
  JWT_SECRET=test-secret-ces-43-contract-suite-0123 \
  AUTH_ISSUER_URL=http://127.0.0.1:8080 \
  GOOGLE_CLIENT_ID=contract-test-client \
  PORT=8080 \
  node test-support/contract-server.js
API_BASE_URL=http://127.0.0.1:8080 \
  JWT_SECRET=test-secret-ces-43-contract-suite-0123 \
  AUTH_ISSUER_URL=http://127.0.0.1:8080 \
  AUTH_AUDIENCE=cestovni \
  GOOGLE_CLIENT_ID=contract-test-client \
  ./tests/contract/run.sh
```

If you override the rate-limit env vars, set the same values on the server and on `run.sh`. `RATE_LIMIT_MUTATIONS_PER_MIN` must stay below 100 or the burst test hits the batch cap first.
