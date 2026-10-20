# Contract tests (API boundary)

**Linear:** [CES-43](https://linear.app/personal-interests-llc/issue/CES-43) (Gate 3 / Gate 6 against the app-owned API)

Validates [`docs/specs/sync-protocol.md`](../../docs/specs/sync-protocol.md) against a running Cestovni API (`server/api/`) and the CES-42 Postgres schema. v1 has one deployment target: this process plus Postgres. The same suite is what CI runs. The dev stub in `server/dev-sync-stub/` is not a target.

## Cases

| File | What it proves |
| ---- | -------------- |
| `test_auth_contract.js` | Missing, empty, garbage, bad signature, expired (`token_expired`), and non-UUID `sub` tokens are 401. A valid token reads the manifest. `/healthz` needs no token. |
| `test_mutations_contract.js` | Insert is `applied` with a server `row_version`. Retry of that `mutation_id` is `duplicate` with the same version. Client `user_id` is ignored. User B cannot see user A's row. A mixed batch keeps the good insert and rejects an unknown table and a bad `fuel_type`. 101 mutations → 413 `batch_too_large`. Bad JSON → 400. Body over 1 MiB → 413 `payload_too_large`. |
| `test_changes_contract.js` | `row_version > since`, ascending pages, `has_more` / `next_since`, `limit` clamped at 500 (`X-Limit-Clamped`), soft-deleted fill-up included with `volume_uL`, cross-user empty page. |
| `test_restore_contract.js` | Manifest order and zero counts for a new user, counts and `max_row_version` after a vehicle and a settings row, user F stays at zero. |
| `test_rate_limit_contract.js` | A batch larger than the per-minute mutation budget is 429 with `Retry-After` and writes nothing. A later single insert still applies. Manifest requests past the changes budget return 429. |

Changes, restore, and rate-limit files mint fresh `sub` values so they do not share RLS visibility or rate-limit windows with user A/B.

## Running

Start the API first ([`server/api/README.md`](../../server/api/README.md)). `JWT_SECRET` must match the server. `npm ci` in `server/api/` must have been run; `run.sh` signs tokens with that `jsonwebtoken` install.

```bash
API_BASE_URL=http://127.0.0.1:8080 JWT_SECRET=dev-secret ./tests/contract/run.sh
```

Optional: `USER_A` and `USER_B` (UUID defaults are the RLS fixture users). `RATE_LIMIT_MUTATIONS_PER_MIN` and `RATE_LIMIT_CHANGES_PER_MIN` must match the server process. The mutation burst test requires the mutation limit to be at most 99.

Exit 0 prints `Contract tests: PASS`. Exit 1 names the failing file.

## CI

[`.github/workflows/contract-tests.yml`](../../.github/workflows/contract-tests.yml) starts Postgres 15, applies `db/migrations/0001_init.sql`, starts this API, and runs `run.sh`. Copy kept at [`ci/contract-tests.yml`](../../ci/contract-tests.yml).
