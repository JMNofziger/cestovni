# Cestovni dev sync stub

Minimal in-memory implementation of `POST /api/v1/mutations` + `GET /api/v1/changes`
from [`docs/specs/sync-protocol.md`](../../docs/specs/sync-protocol.md), built to
unblock the [PWA-lite gate](../../docs/specs/pwa-lite-gate.md) (CES-43 gate slice).

> **Not production.** No persistence, no real auth, no RLS. Replaced by the full
> M3 server (CES-42 / CES-43) before launch.

## Run

```bash
cd server/dev-sync-stub
node server.js              # listens on http://127.0.0.1:8787
PORT=9000 node server.js    # custom port
DEV_BEARER_TOKEN=abc node server.js
```

Requires Node 18+ (built-in `http`, `URL`, `Buffer`). Zero npm dependencies.

## Auth

All `/api/v1/*` requests must carry:

```
Authorization: Bearer <DEV_BEARER_TOKEN>
```

Default token is `dev-cestovni-token`. Mismatch → `401 unauthenticated`. The
single dev `user_id` is hardcoded to `dev-user-0000-0000-000000000000`.

## Endpoints

### `POST /api/v1/mutations`

Per [`sync-protocol.md` §POST /mutations](../../docs/specs/sync-protocol.md#post-mutations).

Request body:

```json
{
  "mutations": [
    {
      "mutation_id": "<uuid>",
      "table": "fill_ups",
      "op": "insert",
      "row_id": "<uuid>",
      "payload": { "vehicle_id": "…", "filled_at": "…", "odometer_m": 12345000, "…": "…" }
    }
  ]
}
```

Response:

```json
{
  "results": [
    { "mutation_id": "…", "row_id": "…", "row_version": 1, "server_updated_at": "…", "status": "applied" }
  ]
}
```

- `status` is one of `applied` | `duplicate` | `rejected`.
- Retry the same `mutation_id` → `duplicate` with the original `row_version`.
- Body size cap: 1 MiB → `413 payload_too_large`.
- Batch size cap: 100 mutations → `413 batch_too_large`.

### `GET /api/v1/changes?table=fill_ups&since=0&limit=200`

Returns rows with `row_version > since`, ordered ascending, capped at `limit` (max 500, default 200).

```json
{
  "table": "fill_ups",
  "rows": [{ "id": "…", "row_version": 1, "updated_at": "…", "deleted_at": null, "…": "…" }],
  "next_since": 1,
  "has_more": false
}
```

### `GET /healthz`

Unauthenticated liveness probe.

```json
{ "ok": true, "row_version": 0 }
```

## Smoke test (curl)

```bash
TOK=dev-cestovni-token
curl -fsS http://127.0.0.1:8787/healthz

curl -fsS -X POST http://127.0.0.1:8787/api/v1/mutations \
  -H "Authorization: Bearer $TOK" \
  -H 'Content-Type: application/json' \
  -d '{
    "mutations": [{
      "mutation_id": "11111111-1111-1111-1111-111111111111",
      "table": "fill_ups",
      "op": "insert",
      "row_id":      "22222222-2222-2222-2222-222222222222",
      "payload": {
        "vehicle_id": "33333333-3333-3333-3333-333333333333",
        "filled_at": "2026-05-29T10:00:00Z",
        "odometer_m": 120000000,
        "volume_uL": 42000000,
        "total_price_cents": 5912,
        "currency_code": "EUR",
        "is_full": true,
        "missed_before": false,
        "odometer_reset": false,
        "notes": null,
        "updated_at": "2026-05-29T10:00:00Z",
        "deleted_at": null,
        "mutation_id": "44444444-4444-4444-4444-444444444444"
      }
    }]
  }'

curl -fsS "http://127.0.0.1:8787/api/v1/changes?table=fill_ups&since=0" \
  -H "Authorization: Bearer $TOK"
```

## Scope

In scope for the gate (CES-43 gate slice):

- `POST /api/v1/mutations` for `fill_ups` insert/update/soft_delete.
- `GET /api/v1/changes` for `fill_ups` (also accepts `vehicles`/`settings` in case the client needs them later).
- Idempotency by `mutation_id`.

Out of scope (full CES-43 / CES-42):

- Real JWT/OIDC and per-user RLS.
- Postgres persistence.
- `GET /restore/manifest`, dead-letter signaling, telemetry.
- Rate limits / `429` handling.
