# Spec: Self-host runbook (backend-only continuity)

**Status:** Draft (executable minimum)  
**Linear:** CES-33

## Goal

Provide a practical continuity path so technical users can run backend services if managed hosting is unavailable.

## Scope (v1 continuity)

- Backend services only (API boundary, Postgres, auth boundary).
- No requirement for extra admin tooling in this phase.
- Operator is assumed to be technically competent (comfortable with Docker, Postgres, CLI).

## Prerequisites

- Docker Engine 24+ and Docker Compose v2+.
- Postgres 15+ (provided by compose or operator-managed).
- A Google OAuth **web** client owned by the operator (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`). Sign-in is Google-only in managed mode and in self-host mode ([ADR 007](adr/007-identity-provider.md)). This API mints the UUID bearer. Google's subject is stored beside that UUID and is never the RLS `user_id`.
- DNS or local network access for client devices to reach the self-hosted API.

## 0. Where to run this (hosting recommendation)

Per [ADR 001 addendum — self-host hosting recommendation](adr/001-addendum-self-host-hosting.md):

- **Recommended: Oracle Cloud "Always Free" tier.** Provision either the AMD `VM.Standard.E2.1.Micro` shape (1 GB RAM — recommended default) or the `VM.Standard.A1.Flex` (Ampere) shape (2 OCPU / 12 GB always-free allocation). Both are standard Ubuntu/Oracle Linux VMs — install Docker, then follow this runbook unmodified. **$0/year.**
- A user's full history (~1000 fill-ups/year) is a few hundred KB/year — every free tier considered has 100-1000x the storage this needs. Sizing is not the constraint; uptime predictability is.
- **Risk:** Oracle is not contractually obligated to keep current Always Free limits (it cut the Ampere allocation in half in June 2026 with no notice). Treat it as best-effort $0, not a guaranteed SLA.
- **Paid fallback (~$48-50/year):** a small Hetzner CX-series VPS if you want a predictable, paid always-on host instead. Because this stack is standard Postgres + `docker compose`, moving from Oracle to a paid VPS is a `pg_dump` / `pg_restore` (see §3-4 below), not a rewrite.
- Full rationale and options considered: [ADR 001 addendum](adr/001-addendum-self-host-hosting.md).

## 1. Bootstrap

```bash
# Clone the repo and enter the backend directory
git clone <repo-url> cestovni && cd cestovni

# .env.example is not in the repo yet. Create .env from the table below.
# Edit .env — see "Environment contract" below for required variables

# Start the backend stack
docker compose up -d
```

### Environment contract

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `POSTGRES_HOST` | yes | Postgres hostname | `db` (compose service) |
| `POSTGRES_PORT` | yes | Postgres port | `5432` |
| `POSTGRES_DB` | yes | Database name | `cestovni` |
| `POSTGRES_USER` | yes | Runtime role username | `cestovni_app` |
| `POSTGRES_PASSWORD` | yes | Runtime role password | *(none — must set)* |
| `POSTGRES_MIGRATION_USER` | yes | Migration role username | `cestovni_migrate` |
| `POSTGRES_MIGRATION_PASSWORD` | yes | Migration role password | *(none — must set)* |
| `JWT_SECRET` | yes | HS256 key for access tokens this API mints. At least 32 characters | *(none — must set)* |
| `AUTH_ISSUER_URL` | yes | Public base URL of this API. Written and checked as access-token `iss` | *(none — must set)* |
| `AUTH_AUDIENCE` | no | Expected access-token audience | `cestovni` |
| `GOOGLE_CLIENT_ID` | yes | Operator's Google OAuth web client id | *(none — must set)* |
| `GOOGLE_CLIENT_SECRET` | yes | Used only by this API when exchanging the authorization code | *(none — must set)* |
| `AUTH_ANDROID_REDIRECT` | no | Where the Google callback sends the Android app | `cestovni://auth/callback` |
| `AUTH_PORTAL_REDIRECT` | when a portal is served | Exact portal callback URL | *(none)* |
| `API_PORT` | no | Port for app-owned API server | `8080` |
| `LOG_LEVEL` | no | Logging verbosity | `info` |

## 2. Migrate and seed

```bash
# Run all pending migrations (uses POSTGRES_MIGRATION_USER)
docker compose exec api ./migrate up

# Seed reference data (units, fuel types, etc.)
docker compose exec api ./migrate seed
```

### Verify migration state

```bash
docker compose exec api ./migrate status
# Expected: all migrations applied, no pending
```

## 3. Backup

```bash
# Dump structured data (excludes ephemeral/local-only tables)
docker compose exec db pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --no-owner \
  --no-privileges \
  -F custom \
  -f /backups/cestovni_$(date +%Y%m%d_%H%M%S).dump
```

Store backups off-host. Recommended cadence: daily or before any migration.

## 4. Restore

```bash
# Stop the API to prevent writes during restore
docker compose stop api

# Restore from backup
docker compose exec db pg_restore \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --clean --if-exists \
  /backups/<backup-file>.dump

# Re-run any migrations that postdate the backup
docker compose exec api ./migrate up

# Restart API
docker compose start api
```

### Verify restore

```bash
# Confirm a signed-in user can read their data through the API
curl -H "Authorization: Bearer <test-token>" http://localhost:8080/api/v1/vehicles
# Expected: 200 with user's vehicle list
```

## 5. Known limitations

- No admin dashboard. Account erasure from the operator's machine is `npm run purge-user` (UUID on stdin) once [CES-85](https://linear.app/personal-interests-llc/issue/CES-85) lands. There is no password-reset CLI.
- Sign-in depends on Google even when Postgres and this API run on the operator's host. The operator registers their own OAuth client. There is no bundled password issuer.
- `docker compose` and `.env.example` are not in the repo yet. The bootstrap commands above describe the intended contract. [CES-86](https://linear.app/personal-interests-llc/issue/CES-86) is the first hosted deploy and does not add the compose file.
- Receipt photos are local-only on client devices; self-host backend has no photo storage.
- Multi-device live sync (v1.x) is not supported in v1 self-host.

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `connection refused` on API port | API container not running or wrong `API_PORT` | `docker compose ps` and check port mapping |
| Migration fails with permission error | Runtime user used instead of migration user | Verify `POSTGRES_MIGRATION_USER` in `.env` |
| JWT verification fails | `AUTH_ISSUER_URL` or `AUTH_AUDIENCE` does not match the access token this API minted | Set `AUTH_ISSUER_URL` to this API's public base URL. It is not Google's issuer URL |
| Restore shows missing tables | Backup predates schema changes | Run `./migrate up` after restore |

## 7. Drill checklist (evidence template)

Use this checklist to validate a self-host deployment. Record results per drill.

| # | Check | Pass/Fail | Notes |
|---|-------|-----------|-------|
| 1 | `docker compose up -d` starts all services without errors | | |
| 2 | `./migrate status` shows all migrations applied | | |
| 3 | Sign in with Google and exchange the login code for an access token ([`identity-provider.md`](identity-provider.md)) | | |
| 4 | `POST /api/v1/vehicles` with valid token returns 201 | | |
| 5 | `GET /api/v1/vehicles` returns created vehicle | | |
| 6 | Cross-user `GET` with different token returns empty (RLS) | | |
| 7 | `pg_dump` completes without errors | | |
| 8 | `pg_restore` + `./migrate up` completes without errors | | |
| 9 | Post-restore `GET /api/v1/vehicles` returns original data | | |
| 10 | API rejects requests with expired/invalid JWT | | |

**Drill date:** _______________  
**Operator:** _______________  
**Result:** Pass / Fail (if fail, file issue before proceeding)

## References

- [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md)
- [`adr/007-identity-provider.md`](adr/007-identity-provider.md)
- [`identity-provider.md`](identity-provider.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
