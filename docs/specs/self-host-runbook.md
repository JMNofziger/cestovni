# Spec: Self-host runbook (backend-only continuity)

**Status:** Draft. The commands below match the code in this repo. Nothing here has run on a hosted machine yet ([CES-101](https://linear.app/personal-interests-llc/issue/CES-101)).  
**Linear:** CES-33

## Goal

Provide a practical continuity path so technical users can run backend services if managed hosting is unavailable.

## Scope (v1 continuity)

- Backend services only (API boundary, Postgres, auth boundary).
- No requirement for extra admin tooling in this phase.
- Operator is assumed to be technically competent (comfortable with Node, Postgres, CLI).

## Prerequisites

- Node 22+ and a checkout of this repo. Migrations run from the checkout ([CES-102](https://linear.app/personal-interests-llc/issue/CES-102) decides whether the Docker image can migrate on its own).
- Postgres 15+ (operator-managed).
- A Google OAuth **web** client owned by the operator (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`). Sign-in is Google-only in managed mode and in self-host mode ([ADR 007](adr/007-identity-provider.md)). This API mints the UUID bearer. Google's subject is stored beside that UUID and is never the RLS `user_id`. Google web clients accept only `http://localhost` or HTTPS redirect URIs, so a phone needs an HTTPS API URL.
- DNS or local network access for client devices to reach the self-hosted API.
- Docker is optional. `server/api/Dockerfile` exists. It has never been built ([CES-102](https://linear.app/personal-interests-llc/issue/CES-102)). There is no Compose file.

## 0. Where to run this (hosting recommendation)

Per [ADR 001 addendum — self-host hosting recommendation](adr/001-addendum-self-host-hosting.md):

- **Recommended: Oracle Cloud "Always Free" tier.** Provision either the AMD `VM.Standard.E2.1.Micro` shape (1 GB RAM — recommended default) or the `VM.Standard.A1.Flex` (Ampere) shape (2 OCPU / 12 GB always-free allocation). Both are standard Ubuntu/Oracle Linux VMs — install Node 22 and Postgres, then follow this runbook. **$0/year.**
- A user's full history (~1000 fill-ups/year) is a few hundred KB/year — every free tier considered has 100-1000x the storage this needs. Sizing is not the constraint; uptime predictability is.
- **Risk:** Oracle is not contractually obligated to keep current Always Free limits (it cut the Ampere allocation in half in June 2026 with no notice). Treat it as best-effort $0, not a guaranteed SLA.
- **Paid fallback (~$48-50/year):** a small Hetzner CX-series VPS if you want a predictable, paid always-on host instead. Because this stack is standard Postgres, moving from Oracle to a paid VPS is a `pg_dump` / `pg_restore` (see §3-4 below), not a rewrite.
- Full rationale and options considered: [ADR 001 addendum](adr/001-addendum-self-host-hosting.md).
- Run **one** API instance. Rate limits are in-process ([CES-94](https://linear.app/personal-interests-llc/issue/CES-94)).

## 1. Bootstrap

```bash
git clone <repo-url> cestovni && cd cestovni/server/api
npm ci --omit=dev
```

Set the variables in [`server/api/.env.example`](../../server/api/.env.example) in the service environment. The API reads the process environment. It does not load a `.env` file. The process refuses to boot unless `JWT_SECRET` (32+ characters), `AUTH_ISSUER_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `DATABASE_URL` are set.

### Database roles

`0001_init.sql` and `0002_identity.sql` create the `NOLOGIN` roles `cestovni_app`, `cestovni_auth`, and `cestovni_purge`. The role in `DATABASE_URL` must be able to `SET ROLE` to all three: a superuser, or:

```sql
GRANT cestovni_app, cestovni_auth, cestovni_purge TO <dsn_role>;
```

Every product transaction runs `SET LOCAL ROLE cestovni_app`, and startup and `/healthz` refuse to serve if that switch does not take effect. Sign-in and purge switch to `cestovni_auth` and `cestovni_purge` the same way. The grant form has been proven only with a superuser DSN in tests. Proving it on a non-superuser host is part of [CES-101](https://linear.app/personal-interests-llc/issue/CES-101).

### Environment contract

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `DATABASE_URL` | yes | Postgres connection string for the DSN role above | *(none — must set)* |
| `JWT_SECRET` | yes | HS256 key for access tokens this API mints. At least 32 characters | *(none — must set)* |
| `AUTH_ISSUER_URL` | yes | Public base URL of this API. Written and checked as access-token `iss` | *(none — must set)* |
| `AUTH_AUDIENCE` | no | Expected access-token audience | `cestovni` |
| `GOOGLE_CLIENT_ID` | yes | Operator's Google OAuth web client id | *(none — must set)* |
| `GOOGLE_CLIENT_SECRET` | yes | Used only by this API when exchanging the authorization code | *(none — must set)* |
| `AUTH_ANDROID_REDIRECT` | no | Where the Google callback sends the Android app | `cestovni://auth/callback` |
| `AUTH_PORTAL_REDIRECT` | when a portal is served | Exact portal callback URL | *(none)* |
| `CORS_ORIGINS` | no | Comma-separated browser origins allowed to call the API. Pin it when a portal is served | `*` |
| `PORT` | no | Port for the API server | `8080` |
| `HOST` | no | Bind address | `0.0.0.0` |
| `TRUST_PROXY_HOPS` | no | `X-Forwarded-For` hops to trust, counted from the right | `0` |

Rate-limit variables are listed in [`server/api/README.md`](../../server/api/README.md).

## 2. Migrate

Migrations apply from the checkout with a superuser (or role-creating) `DATABASE_URL`. The API never migrates on boot.

```bash
cd server/api
DATABASE_URL=postgresql://<superuser>:<password>@<host>:5432/<db> npm run migrate
# Expected: "migrate: 2 applied, 0 already recorded" on a new database
```

A second run applies nothing. There are no seed data and no `status` command: the `schema_migrations` table lists applied versions. Start the API after migrating:

```bash
DATABASE_URL=postgresql://<dsn_role>:<password>@<host>:5432/<db> \
  JWT_SECRET=... AUTH_ISSUER_URL=https://<public-host> \
  GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... \
  npm start
curl -fsS http://localhost:8080/healthz
# Expected: {"ok":true}
```

## 3. Backup

```bash
# Keep privileges. Do NOT pass --no-privileges.
pg_dump "$DATABASE_URL" --no-owner -F custom \
  -f "cestovni_$(date +%Y%m%d_%H%M%S).dump"
```

`--no-privileges` drops every `GRANT` on the product and identity tables. A database restored from such a dump has the schema and the rows, but `cestovni_app`, `cestovni_auth`, and `cestovni_purge` can read nothing, and `npm run migrate` will not reapply the grants because the versions are already recorded. This was measured on Postgres 16: all three privilege probes returned true on the source, false after a restore from a `--no-privileges` dump, and true after a restore from a dump without that flag.

Roles are cluster-level and are not in the dump. The migrations create them. On a new Postgres cluster, run `npm run migrate` against an empty database first so the roles exist, then restore. On a cluster that already has the roles, restore into any database.

Store backups off-host. Recommended cadence: daily or before any migration.

## 4. Restore

```bash
# Stop the API to prevent writes during restore (stop the service you run it as)

# The three roles must already exist in the cluster (see §3)
pg_restore -d "$DATABASE_URL" --clean --if-exists --no-owner <backup-file>.dump

# Apply any migrations that postdate the backup
cd server/api && npm run migrate

# Start the API again
```

### Verify restore

```bash
# Roles still hold their grants
psql "$DATABASE_URL" -Atc "select has_table_privilege('cestovni_app','vehicles','INSERT'), has_table_privilege('cestovni_auth','users','INSERT'), has_table_privilege('cestovni_purge','vehicles','DELETE')"
# Expected: t|t|t

# A signed-in user can read their data through the API
curl -H "Authorization: Bearer <access-token>" "http://localhost:8080/api/v1/changes?table=vehicles"
# Expected: 200 with the user's vehicle rows
```

A live restore against a hosted database has not been drilled yet. GitHub issue [41](https://github.com/JMNofziger/cestovni/issues/41) tracks the Postgres restore test.

## 5. Erasure

`DELETE /api/v1/account` with the bearer and `{"confirm": true}` deletes the signed-in user's rows and identity record (204). An operator who cannot ask the person to sign in runs the same purge from the checkout:

```bash
cd server/api && echo <user-uuid> | DATABASE_URL=... npm run purge-user
# exit 0: deleted. exit 1: unknown user or purge failed. exit 2: not a UUID.
```

The script prints row counts per table and never the id or any token. The DSN role needs `cestovni_auth` and `cestovni_purge` as in [Database roles](#database-roles). Deleted rows stay in any backup taken before the purge until that backup expires. See [`identity-provider.md`](identity-provider.md) § Account deletion.

## 6. Known limitations

- No admin dashboard and no password-reset CLI. Erasure is §5.
- Sign-in depends on Google even when Postgres and this API run on the operator's host. The operator registers their own OAuth client. There is no bundled password issuer.
- No `docker compose` file is in the repo, and none is planned for v1. `server/api/Dockerfile` has not been built or run ([CES-102](https://linear.app/personal-interests-llc/issue/CES-102)). Its migration script resolves `db/migrations` outside the image, so run migrations from a checkout or set `MIGRATIONS_DIR`.
- The API image also copies `test-support/`, which holds a fake Google verifier for tests. The image's `CMD` never starts it. Do not run it on a host ([CES-102](https://linear.app/personal-interests-llc/issue/CES-102) removes it).
- One API instance only ([CES-94](https://linear.app/personal-interests-llc/issue/CES-94)).
- Receipt photos are local-only on client devices; self-host backend has no photo storage.
- Multi-device live sync (v1.x) is not supported in v1 self-host.

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `connection refused` on API port | API process not running or wrong `PORT` | Check the service and `PORT` |
| API exits at boot naming a variable | A required variable is missing or `JWT_SECRET` is under 32 characters | Set the variable in the service environment. `.env` files are not read |
| `/healthz` fails or boot refuses with a role error | DSN role cannot `SET ROLE cestovni_app` | Use a superuser or `GRANT` the three roles to it |
| `permission denied for table` after a restore | Dump was taken with `--no-privileges` | Re-restore from a dump taken without it, or re-apply the grants from `0001_init.sql` and `0002_identity.sql` |
| `npm run migrate` fails creating roles | DSN role cannot `CREATE ROLE` | Run the migration with a superuser DSN. Run the API with the DSN role |
| JWT verification fails | `AUTH_ISSUER_URL` or `AUTH_AUDIENCE` does not match the access token this API minted | Set `AUTH_ISSUER_URL` to this API's public base URL. It is not Google's issuer URL |
| Browser sign-in returns to the wrong place | `AUTH_PORTAL_REDIRECT` or `CORS_ORIGINS` does not match the portal origin | Set both to the portal's exact origin and callback |

## 8. Drill checklist (evidence template)

Use this checklist to validate a self-host deployment. Record results per drill.

| # | Check | Pass/Fail | Notes |
|---|-------|-----------|-------|
| 1 | `npm run migrate` applies `0001` and `0002`; a second run applies nothing | | |
| 2 | `GET /healthz` returns `{"ok":true}` | | |
| 3 | Sign in with Google and exchange the login code for an access token ([`identity-provider.md`](identity-provider.md)) | | |
| 4 | `POST /api/v1/mutations` with the token upserts a vehicle (`status: applied`) | | |
| 5 | `GET /api/v1/changes?table=vehicles` returns the vehicle | | |
| 6 | A second user's `GET /api/v1/changes?table=vehicles` returns no rows (RLS) | | |
| 7 | `pg_dump` (without `--no-privileges`) completes without errors | | |
| 8 | `pg_restore` into a fresh migrated database, then `npm run migrate`, completes; the privilege probe in §4 returns `t\|t\|t` | | |
| 9 | After restore, `GET /api/v1/changes?table=vehicles` returns the original data | | |
| 10 | The API rejects an expired or invalid bearer with 401 | | |
| 11 | `POST /api/v1/auth/refresh` rotates; the old refresh token is rejected | | |
| 12 | `DELETE /api/v1/account` returns 204 and the user's rows are gone | | |

**Drill date:** _______________  
**Operator:** _______________  
**Result:** Pass / Fail (if fail, file issue before proceeding)

## References

- [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md)
- [`adr/007-identity-provider.md`](adr/007-identity-provider.md)
- [`identity-provider.md`](identity-provider.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
