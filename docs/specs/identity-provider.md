# Spec: Identity provider

**Status:** Accepted contract. The running API does not implement it yet.
**Date:** 2026-11-07
**Decision:** [ADR 007](adr/007-identity-provider.md)
**Linear:** [CES-79](https://linear.app/personal-interests-llc/issue/CES-79)

Today `server/api` verifies a hand-signed HS256 bearer and has no `users` table. Contract tests mint those tokens with `JWT_SECRET`. This document is the contract those issues implement. Until [CES-84](https://linear.app/personal-interests-llc/issue/CES-84) lands, the code in `server/api/src/auth.js` remains the behavior.

## Identity chain

One UUID, allocated by this API on first Google sign-in:

`users.id` = access-token `sub` = `app.user_id` = every product `user_id` = `settings.id` after sign-in.

`user_key_hash` is the first 8 hex characters of SHA-256 over `settings.id` ([`export-import.md`](export-import.md)). It changes once, when Android rebinds a bootstrap settings row to `users.id`.

Google’s `sub` is stored in `users.google_sub`. It is not a UUID. It is never written to `app.user_id`, to a product `user_id`, or to `settings.id`.

The same `google_sub` on Android and in the portal is the same `users.id` and the same backup. Two Google accounts are two users. This product does not merge them.

## Sign-in

Google is the only sign-in door. There is no password, no invite code, no email-and-password form, and no operator password reset.

The client does not embed a Google SDK and does not call Google. The API performs the OAuth authorization-code flow with PKCE.

1. The client opens `GET /api/v1/auth/google/start?client=android` or `client=portal` in a browser (Chrome custom tab on Android, a navigation in the portal).
2. The API redirects to Google. Scope is `openid email`. The request does not set `access_type=offline` and does not ask for a Google refresh token.
3. Google redirects to `GET /api/v1/auth/google/callback`.
4. The API checks the ID token, finds or creates `users`, and redirects to an allowlisted app URL with a one-time login code.
5. The client calls `POST /api/v1/auth/google/exchange` with that code and receives the session body below.

`POST /api/v1/auth/google` with `{id_token}` mints the same session. The browser callback uses that verifier internally. Contract tests call the route with a test ID token (see [Test tokens](#test-tokens)). A production client uses the browser flow.

### Google ID token checks

- JWKS: `https://www.googleapis.com/oauth2/v3/certs`, cached in process, refreshed when `kid` is unknown.
- Algorithm RS256.
- `iss` is `https://accounts.google.com` or `accounts.google.com`.
- `aud` equals `GOOGLE_CLIENT_ID`.
- `exp` is in the future. `iat` is no older than 10 minutes.
- `nonce` matches the value stored with the OAuth state, when the token came from our callback.
- `sub` is present, at most 255 characters.
- When `email` is present, `email_verified` is `true`. The email is stored for display. It is not the primary key and it is not unique.

### Session body

```json
{
  "user_id": "<uuid>",
  "email": "person@gmail.com",
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "<opaque>",
  "refresh_expires_in": 5184000
}
```

`email` may be `null`. Clients take `user_id` from this body. They do not decode the access token.

## Access token

HS256, `JWT_SECRET` at least 32 characters. Claims:

| Claim | Value |
| --- | --- |
| `iss` | `AUTH_ISSUER_URL` (the public base URL of this API) |
| `aud` | `AUTH_AUDIENCE`, default `cestovni` |
| `sub` | `users.id` |
| `sid` | `auth_sessions.id` |
| `iat`, `exp` | `exp` is 900 seconds after `iat` |

No email and no Google subject in the token. `typ` is unused.

After [CES-84](https://linear.app/personal-interests-llc/issue/CES-84), verification requires HS256, `iss`, `aud`, a present `exp` at most 15 minutes after `iat`, a UUID `sub`, a UUID `sid`, and a live session for that user. The session lookup may be cached in process for 30 seconds. Logout and account deletion drop that cache entry in the same process.

## Refresh

Opaque 32 random bytes, base64url. The database stores SHA-256 only.

- Rotated on every use.
- Idle expiry 60 days, capped by an absolute session expiry of 180 days from `auth_sessions.created_at`.
- A second use within 30 seconds is a lost response: the API issues a new successor and does not revoke the session.
- A later reuse revokes the whole session (`reuse_detected`) and returns `401 refresh_invalid`.
- Unknown, expired, and revoked tokens return the same `401 refresh_invalid`.

Rotating `JWT_SECRET` invalidates access tokens only. Refresh tokens stay valid.

## Endpoints

| Method | Path | Auth | Body | Success |
| --- | --- | --- | --- | --- |
| `GET` | `/api/v1/auth/google/start?client=android\|portal` | public | — | 302 to Google |
| `GET` | `/api/v1/auth/google/callback` | public | query `code`, `state` | 302 to the allowlisted app URL with `?code=` |
| `POST` | `/api/v1/auth/google` | public | `{id_token}` | 200 session |
| `POST` | `/api/v1/auth/google/exchange` | public | `{code}` | 200 session |
| `POST` | `/api/v1/auth/refresh` | public | `{refresh_token}` | 200 session |
| `POST` | `/api/v1/auth/logout` | public | `{refresh_token}` | 204, idempotent |
| `DELETE` | `/api/v1/account` | bearer | `{id_token}` | 204 |

`client` is an enum. The start route does not accept a free redirect URL.

- `android` returns to `AUTH_ANDROID_REDIRECT` (default `cestovni://auth/callback`).
- `portal` returns to the single URL in `AUTH_PORTAL_REDIRECT` for that deployment (the portal’s `/auth/callback`). Local dev sets this to the dev origin.

OAuth `state` and the PKCE verifier live in `auth_oauth_states` for 10 minutes. The one-time login code lives in `auth_login_transactions` for 60 seconds, single use, stored as a hash. The session is created at exchange time, so the refresh token is not written down before the client receives it.

Logout is public so an expired access token can still revoke the refresh token. The client always clears local tokens after it calls logout, including when the network fails.

### Errors

Envelope stays `{error: {code, message, retriable}}`.

| HTTP | Code | When |
| --- | --- | --- |
| 400 | `bad_request` | Malformed body |
| 400 | `oauth_state_invalid` | Bad, expired, or reused OAuth state |
| 400 | `login_code_invalid` | Bad, expired, or reused login code |
| 401 | `google_token_invalid` | ID token failed the checks above, or its `sub` does not match the bearer user on account deletion |
| 401 | `refresh_invalid` | Refresh token cannot be used |
| 401 | `unauthenticated` | Sync route, missing or rejected access token |
| 401 | `token_expired` | Access token past `exp` |
| 429 | `rate_limited` | The only retriable auth error. Includes `Retry-After` |

Auth bodies are JSON, capped at 1 KiB. Responses send `Cache-Control: no-store`.

Rate limits are in-process, per IP (socket address, or the entry `TRUST_PROXY_HOPS` from the right of `X-Forwarded-For`; default hops is 0):

- `POST /auth/google` and `POST /auth/google/exchange`: 20 per 15 minutes
- `GET /auth/google/start`: 30 per 15 minutes
- `POST /auth/refresh`: 60 per hour

Deploy with max instances = 1. The rate limiter and the session cache are per process.

### Sync 401

On `401` from a sync route the client refreshes once, retries the sync call once, and only then pauses the outbox and asks the person to sign in again. A network failure on refresh stays retriable and does not clear the session. `401 google_token_invalid` from the sign-in routes is a failed sign-in. Clients do not treat it as a stale backup token.

## Offline Android and the portal

Logging a fill-up on Android does not contact Google or this API. After the first successful sign-in, Android keeps the refresh token in Keystore-backed storage and the access token in memory. Later syncs call `POST /api/v1/auth/refresh`. They do not open Google again until the refresh token is revoked, expires, or the absolute 180-day cap is reached.

A new install that has never signed in can log locally. Sync stays paused until Google and this API are both reachable. The settings rebind runs before the first flush.

The portal is online-only. It keeps the access token and the refresh token in `sessionStorage` ([ADR 006](adr/006-browser-client.md)). Closing the tab drops them. The next visit starts at Google again. The portal and Android share rows only through the server, under one `users.id`. The portal has no offline queue.

An offline Android queue and an online portal edit meet through the existing `row_version` rules when the phone is back online.

## Settings id

The portal creates `settings` with `id` equal to `user_id` from the session body.

Android bootstraps a random `settings.id` before any account exists. On `signedIn`, [CES-77](https://linear.app/personal-interests-llc/issue/CES-77) rebinds that row:

- Server has no settings row: rewrite the local id to `user_id` and send the insert.
- Server already has the row: restore wins ([ADR 002](adr/002-backup-sync-layer.md)).
- Local row is already synced to a different `user_id`: refuse the sign-in and change nothing.

## Account deletion

`DELETE /api/v1/account` requires the bearer and a fresh Google ID token whose `sub` equals `users.google_sub` for that user. One transaction, then the in-process session cache drops that user:

1. As `cestovni_purge`, with `app.user_id` set: `DELETE` every row for that user in `settings`, `maintenance_events`, `maintenance_rules`, `fill_ups`, `vehicles`, including soft-deleted rows.
2. As `cestovni_auth`: `DELETE` the `users` row. Sessions, refresh tokens, and login transactions cascade.

The table list is `TABLES` in `server/api/src/schema.js`. A guard test fails when a public table with a `user_id` column is missing from that list.

Host backups and the provider’s restore window keep deleted rows until that retention ends. The compliance doc states that limit. There is no claim of instant erasure from backups.

An operator at the machine can run the same purge for an erasure request when the person cannot sign in: `npm run purge-user` in `server/api/`, UUID read from stdin. That script is [CES-85](https://linear.app/personal-interests-llc/issue/CES-85). It is not a general admin CLI.

Telemetry pepper deletion stays on [CES-46](https://linear.app/personal-interests-llc/issue/CES-46). When that table exists, the purge function deletes it too.

## Schema (identity migration)

`db/migrations/0002_identity.sql`, applied by the migration runner in [CES-80](https://linear.app/personal-interests-llc/issue/CES-80). No foreign keys from the five product tables to `users`.

- `users`: `id UUID` primary key default `gen_random_uuid()`, `google_sub TEXT NOT NULL` unique, `email TEXT NULL`, `created_at`.
- `auth_sessions`: `id`, `user_id` references `users` on delete cascade, `created_at`, `last_used_at`, `expires_at`, `revoked_at`, `revoked_reason`.
- `auth_refresh_tokens`: `id`, `session_id` cascade, `token_hash BYTEA NOT NULL UNIQUE`, `created_at`, `expires_at`, `used_at`.
- `auth_oauth_states`: hashed state, PKCE verifier, `client`, `nonce`, `expires_at`.
- `auth_login_transactions`: hashed one-time code, `google_sub`, `email`, `expires_at`, `consumed_at`.

Roles `cestovni_auth` and `cestovni_purge` are `NOLOGIN`. Grants are in [ADR 007](adr/007-identity-provider.md). Identity tables have no RLS. Access is grant-only, and `cestovni_app` has no grant.

## Environment

| Variable | Required | Meaning |
| --- | --- | --- |
| `JWT_SECRET` | yes | HS256 key, at least 32 characters |
| `AUTH_ISSUER_URL` | yes | Public base URL of this API. Written and checked as `iss` |
| `AUTH_AUDIENCE` | no | Default `cestovni` |
| `GOOGLE_CLIENT_ID` | yes | OAuth web client id. `aud` of the ID token |
| `GOOGLE_CLIENT_SECRET` | yes | Used by the server when it exchanges the authorization code. Never shipped in a client |
| `AUTH_ANDROID_REDIRECT` | no | Default `cestovni://auth/callback` |
| `AUTH_PORTAL_REDIRECT` | yes for portal | Exact callback URL of the portal |
| `TRUST_PROXY_HOPS` | no | Default `0` |
| `CORS_ORIGINS` | yes for portal | Portal origin allowed to call exchange, refresh, logout, and `DELETE /account` |
| `GOOGLE_ID_TOKEN_TEST_SECRET` | tests only | See below. The process refuses to start when this is set and `NODE_ENV` is not `test` |

Google Cloud Console: one Web application client whose authorized redirect URI is `{AUTH_ISSUER_URL}/api/v1/auth/google/callback`. Publish the consent screen for the non-sensitive scopes `openid` and `email`. Local development may use `http://127.0.0.1:8080` as that URI.

## Test tokens

`tests/contract/` must not call Google. When `NODE_ENV=test` and `GOOGLE_ID_TOKEN_TEST_SECRET` is set (at least 32 characters), `POST /api/v1/auth/google` also accepts an HS256 JWT signed with that secret whose `iss` is `https://accounts.google.com`, `aud` is `GOOGLE_CLIENT_ID`, and `sub`, `email`, `email_verified`, `iat`, and `exp` pass the same checks as a real ID token.

The production process exits on startup if `GOOGLE_ID_TOKEN_TEST_SECRET` is set. CI sets `NODE_ENV=test` only on the contract-test server.

[CES-84](https://linear.app/personal-interests-llc/issue/CES-84) creates users A and B through this route and uses the returned access tokens. Hand-signed API tokens stop working at that cutover.

## Out of scope

- Portal screens. The portal calls these endpoints later, behind [CES-74](https://linear.app/personal-interests-llc/issue/CES-74).
- Passwords, invites, email delivery, magic links, MFA, passkeys.
- A Google refresh token, Google offline access, or a Google Sign-In SDK in the client.
- An admin web UI.
- Replacing this issuer with another OIDC provider. A later subject can map onto the same `users.id`. v1 does not build that.
- Hosting vendor selection. That is [CES-86](https://linear.app/personal-interests-llc/issue/CES-86).
