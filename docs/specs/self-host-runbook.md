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
- A compatible OIDC/JWT auth provider that can issue tokens with the same claim model as managed mode (see ADR 001 identity model).
- DNS or local network access for client devices to reach the self-hosted API.

## 1. Bootstrap

```bash
# Clone the repo and enter the backend directory
git clone <repo-url> cestovni && cd cestovni

# Copy env template and fill in required values
cp .env.example .env
# Edit .env — see "Environment contract" below for required variables

# Start the backend stack
docker compose up -d
```

### Environment contract (`.env.example`)

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `POSTGRES_HOST` | yes | Postgres hostname | `db` (compose service) |
| `POSTGRES_PORT` | yes | Postgres port | `5432` |
| `POSTGRES_DB` | yes | Database name | `cestovni` |
| `POSTGRES_USER` | yes | Runtime role username | `cestovni_app` |
| `POSTGRES_PASSWORD` | yes | Runtime role password | *(none — must set)* |
| `POSTGRES_MIGRATION_USER` | yes | Migration role username | `cestovni_migrate` |
| `POSTGRES_MIGRATION_PASSWORD` | yes | Migration role password | *(none — must set)* |
| `AUTH_ISSUER_URL` | yes | OIDC issuer URL for JWT verification | *(none — must set)* |
| `AUTH_AUDIENCE` | no | Expected JWT audience claim | `cestovni` |
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

- No admin dashboard; all management is via CLI and direct Postgres access.
- Auth provider setup is operator's responsibility; managed mode's provider is not bundled.
- Receipt photos are local-only on client devices; self-host backend has no photo storage.
- Multi-device live sync (v1.x) is not supported in v1 self-host.

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `connection refused` on API port | API container not running or wrong `API_PORT` | `docker compose ps` and check port mapping |
| Migration fails with permission error | Runtime user used instead of migration user | Verify `POSTGRES_MIGRATION_USER` in `.env` |
| JWT verification fails | `AUTH_ISSUER_URL` mismatch or unreachable issuer | Verify issuer URL and network access |
| Restore shows missing tables | Backup predates schema changes | Run `./migrate up` after restore |

## 7. Drill checklist (evidence template)

Use this checklist to validate a self-host deployment. Record results per drill.

| # | Check | Pass/Fail | Notes |
|---|-------|-----------|-------|
| 1 | `docker compose up -d` starts all services without errors | | |
| 2 | `./migrate status` shows all migrations applied | | |
| 3 | Create test user via auth provider; obtain valid JWT | | |
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
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
