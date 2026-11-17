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
2. The API redirects to Google. Scope is `openid email`. The request sets `prompt=select_account` so a person with several Google accounts chooses one. It does not set `access_type=offline` and does not ask for a Google refresh token.
3. Google redirects to `GET /api/v1/auth/google/callback`.
4. The API exchanges the authorization code at `https://oauth2.googleapis.com/token` (`grant_type=authorization_code`, `code`, `client_id`, `client_secret`, `redirect_uri` = `{AUTH_ISSUER_URL}/api/v1/auth/google/callback`, `code_verifier`). It checks the returned ID token and redirects to an allowlisted app URL with a one-time login code that holds the Google `sub` and email. `users` is found or created at step 5, so an abandoned sign-in creates no user.
5. The client calls `POST /api/v1/auth/google/exchange` with that code and receives the session body below.

`POST /api/v1/auth/google` with `{id_token}` mints the same session. The browser callback uses the same verifier internally. Contract tests call the route with a fake verifier injected by the test server (see [Test seam](#test-seam)). A production client uses the browser flow.

### Google ID token checks

- JWKS: `https://www.googleapis.com/oauth2/v3/certs`, cached in process, refreshed when `kid` is unknown.
- Algorithm RS256.
- `iss` is `https://accounts.google.com` or `accounts.google.com`.
- `aud` equals `GOOGLE_CLIENT_ID`.
- `exp` is in the future. `iat` is no older than 10 minutes. Allow 60 seconds of clock skew on both.
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

After [CES-84](https://linear.app/personal-interests-llc/issue/CES-84), verification requires HS256, `iss`, `aud`, a present `exp` at most 15 minutes after `iat`, a UUID `sub`, a UUID `sid`, and a live session for that user. The live-session check is one primary-key lookup on every sync request. There is no session cache in v1, so logout and account deletion take effect on the next request. A cache is tracked debt ([CES-93](https://linear.app/personal-interests-llc/issue/CES-93)).

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
| `DELETE` | `/api/v1/account` | bearer | `{confirm: true}` | 204 |

`client` is an enum. The start route does not accept a free redirect URL.

- `android` returns to `AUTH_ANDROID_REDIRECT` (default `cestovni://auth/callback`).
- `portal` returns to the single URL in `AUTH_PORTAL_REDIRECT` for that deployment (the portal’s `/auth/callback`). Local dev sets this to the dev origin.

OAuth `state` and the PKCE verifier live in `auth_oauth_states` for 10 minutes. The one-time login code lives in `auth_login_transactions` for 60 seconds, single use, stored as a hash. The session is created at exchange time, so the refresh token is not written down before the client receives it.

Callback failures. A `state` that is missing, unknown, expired, or already used returns `400 oauth_state_invalid` as JSON (no redirect target is trusted without a valid state). When `state` is valid but sign-in cannot finish (Google sent `error=access_denied`, the code exchange failed, or the ID token failed the checks), the API redirects to that client's allowlisted URL with `?error=<code>` where `<code>` is `access_denied` or `google_token_invalid`, and no login code. The state row is consumed in every case.

Opportunistic cleanup: `start` and `exchange` both call `sweepExpired()`, which deletes expired `auth_oauth_states` and `auth_login_transactions` rows. Expired sessions and refresh tokens are not swept in v1 ([CES-96](https://linear.app/personal-interests-llc/issue/CES-96)).

Logout is public so an expired access token can still revoke the refresh token. The client always clears local tokens after it calls logout, including when the network fails.

### Errors

Envelope stays `{error: {code, message, retriable}}`.

| HTTP | Code | When |
| --- | --- | --- |
| 400 | `bad_request` | Malformed body, or `DELETE /account` without `confirm: true` |
| 400 | `oauth_state_invalid` | Bad, expired, or reused OAuth state |
| 400 | `login_code_invalid` | Bad, expired, or reused login code |
| 401 | `google_token_invalid` | ID token failed the checks above (`POST /auth/google` only; the browser callback reports it as a redirect, see below) |
| 401 | `refresh_invalid` | Refresh token cannot be used |
| 401 | `unauthenticated` | Sync route, missing or rejected access token |
| 401 | `token_expired` | Access token past `exp` |
| 429 | `rate_limited` | The only retriable auth error. Includes `Retry-After` |

Auth bodies are JSON, capped at 1 KiB. Responses send `Cache-Control: no-store`.

Rate limits are in-process, per IP (socket address, or the entry `TRUST_PROXY_HOPS` from the right of `X-Forwarded-For`; default hops is 0):

- `POST /auth/google` and `POST /auth/google/exchange`: 20 per 15 minutes
- `GET /auth/google/start`: 30 per 15 minutes
- `POST /auth/refresh`: 60 per hour

Deploy with max instances = 1. The rate limiter is per process ([CES-94](https://linear.app/personal-interests-llc/issue/CES-94)).

### Sync 401

On `401` from a sync route the client refreshes once, retries the sync call once, and only then pauses the outbox and asks the person to sign in again. A network failure on refresh stays retriable and does not clear the session. `401 google_token_invalid` from `POST /auth/google` is a failed sign-in. Clients do not treat it as a stale backup token.

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

`DELETE /api/v1/account` requires the bearer and the body `{"confirm": true}`. v1 does not ask Google again: the client never holds a Google ID token, so a re-auth step needs its own browser round trip ([CES-92](https://linear.app/personal-interests-llc/issue/CES-92)). One transaction on one connection:

1. `pg_advisory_xact_lock(hashtextextended('user:' || <user_id>, 0))`. The mutations handler takes the same lock at the start of its transaction, so a write in flight finishes first and no row is created after the purge.
2. `SET LOCAL ROLE cestovni_purge`, with `app.user_id` set: `DELETE` every row for that user, including soft-deleted rows, in this order: `maintenance_events`, `maintenance_rules`, `fill_ups`, `vehicles`, `settings` (child before parent; the foreign keys have no cascade).
3. `RESET ROLE`, then `SET LOCAL ROLE cestovni_auth`: `DELETE FROM auth_login_transactions WHERE google_sub = <users.google_sub>`, then `DELETE` the `users` row. Sessions and refresh tokens cascade. Login transactions do not cascade because the table has no `user_id`.

The next sync request with the old access token fails because its session row is gone. The refresh token fails for the same reason.

The delete order is `PURGE_ORDER` in `server/api/src/identity/purge.js`. A guard test fails unless `PURGE_ORDER` has exactly the same members as `TABLES` in `server/api/src/schema.js` and as the public tables that have a `user_id` column.

Host backups and the provider’s restore window keep deleted rows until that retention ends. The compliance doc states that limit. There is no claim of instant erasure from backups.

An operator at the machine can run the same purge for an erasure request when the person cannot sign in: `npm run purge-user` in `server/api/`, UUID read from stdin. That script is [CES-85](https://linear.app/personal-interests-llc/issue/CES-85). It is not a general admin CLI.

Telemetry pepper deletion stays on [CES-46](https://linear.app/personal-interests-llc/issue/CES-46). When that table exists, the purge function deletes it too.

## Schema (identity migration)

`db/migrations/0002_identity.sql`, applied by the migration runner in [CES-80](https://linear.app/personal-interests-llc/issue/CES-80). No foreign keys from the five product tables to `users`.

- `users`: `id UUID` primary key default `gen_random_uuid()`, `google_sub TEXT NOT NULL` unique, `email TEXT NULL`, `created_at`.
- `auth_sessions`: `id`, `user_id` references `users` on delete cascade, `created_at`, `last_used_at`, `expires_at`, `revoked_at`, `revoked_reason`.
- `auth_refresh_tokens`: `id`, `session_id` cascade, `token_hash BYTEA NOT NULL UNIQUE`, `created_at`, `expires_at`, `used_at`.
- `auth_oauth_states`: hashed state, PKCE verifier, `client`, `nonce`, `expires_at`.
- `auth_login_transactions`: hashed one-time code, `google_sub`, `email`, `expires_at`, `consumed_at`. No `user_id` and no foreign key. Account deletion removes its rows by `google_sub`.

Roles `cestovni_auth` and `cestovni_purge` are `NOLOGIN`. Grants are in [ADR 007](adr/007-identity-provider.md). Identity tables have no RLS. Access is grant-only, and `cestovni_app` has no grant.

## Environment

| Variable | Required | Meaning |
| --- | --- | --- |
| `JWT_SECRET` | yes | HS256 key, at least 32 characters |
| `AUTH_ISSUER_URL` | yes | Public base URL of this API. Written and checked as `iss` |
| `AUTH_AUDIENCE` | no | Default `cestovni` |
| `GOOGLE_CLIENT_ID` | yes | OAuth web client id. `aud` of the ID token |
| `GOOGLE_CLIENT_SECRET` | yes in the production entry | Used by the server when it exchanges the authorization code. Never shipped in a client. The contract-test entry does not need it |
| `AUTH_ANDROID_REDIRECT` | no | Default `cestovni://auth/callback` |
| `AUTH_PORTAL_REDIRECT` | yes for portal | Exact callback URL of the portal |
| `TRUST_PROXY_HOPS` | no | Default `0` |
| `CORS_ORIGINS` | yes for portal | Portal origin allowed to call exchange, refresh, logout, and `DELETE /account` |

Google Cloud Console: one Web application client whose authorized redirect URI is `{AUTH_ISSUER_URL}/api/v1/auth/google/callback`. Publish the consent screen for the non-sensitive scopes `openid` and `email`. Local development may use `http://127.0.0.1:8080` as that URI.

## Test seam

`tests/contract/` must not call Google, and production code carries no test backdoor. There is no test secret, no test environment variable, and no `NODE_ENV` branch in the API.

- `server/api/src/app.js` exports `createServer({verifyIdToken, exchangeAuthCode, trustProxyHops?})`. `verifyIdToken(idToken, {nonce?}) -> {googleSub, email|null}` throws on a failed check. `exchangeAuthCode({code, codeVerifier, redirectUri}) -> idToken` performs the Google token-endpoint call. `trustProxyHops` defaults to `TRUST_PROXY_HOPS` or 0. The contract server passes 1.
- `server/api/src/server.js` (`npm start`) calls `createServer()` with the real Google implementations and listens.
- `server/api/test-support/contract-server.js` calls `createServer()` with fakes and listens. CI and `tests/contract/run.sh` start this file. It is never a deploy target.
- The fake `verifyIdToken` accepts an HS256 JWT signed with a constant defined in that file, with the same claims a Google ID token carries (`sub`, `email`, `email_verified`, `nonce`). The fake `exchangeAuthCode` turns the code `fake:<googleSub>:<email>:<nonce>` into such a token, so the contract suite drives start, callback, and exchange offline, including the `nonce` and `state` checks.
- The real Google round trip is proven once by hand on staging ([CES-97](https://linear.app/personal-interests-llc/issue/CES-97)).

[CES-84](https://linear.app/personal-interests-llc/issue/CES-84) creates users A and B through `POST /api/v1/auth/google` on the contract server and uses the returned access tokens. Hand-signed API tokens stop working at that cutover.

## Decisions of 2026-11-16

Made to reach a stable MVP for one to five people on one API instance. Each shortcut has a trigger and an owner issue under [CES-90](https://linear.app/personal-interests-llc/issue/CES-90).

| Decision | Instead of | Debt |
| --- | --- | --- |
| No session cache. One primary-key lookup per sync request | 30-second in-process cache | [CES-93](https://linear.app/personal-interests-llc/issue/CES-93) |
| `DELETE /account` takes bearer plus `{confirm: true}` | A fresh Google ID token (the client never has one) | [CES-92](https://linear.app/personal-interests-llc/issue/CES-92) |
| Dependency-injected verifier and code exchange in a separate test entry | `GOOGLE_ID_TOKEN_TEST_SECRET` and a `NODE_ENV=test` branch in production code | none |
| Android returns on the custom scheme without client PKCE | PKCE plus App Links | [CES-91](https://linear.app/personal-interests-llc/issue/CES-91) |
| Advisory lock per user shared by mutations and purge | Accepting a rare orphan row after deletion | none |
| Only expired OAuth states and login codes are cleaned, on use | A scheduled sweep of every identity table | [CES-96](https://linear.app/personal-interests-llc/issue/CES-96) |
| In-process rate limits, max instances = 1 | Shared limiter store | [CES-94](https://linear.app/personal-interests-llc/issue/CES-94) |
| Minimal migration runner | Checksums, separate migration DSN, down migrations | [CES-95](https://linear.app/personal-interests-llc/issue/CES-95) |
| Schema as listed: `auth_login_transactions` has no `user_id` | A foreign key and cascade | none (purge deletes by `google_sub`) |

## Out of scope

- Portal screens. The portal calls these endpoints later, behind [CES-74](https://linear.app/personal-interests-llc/issue/CES-74).
- Passwords, invites, email delivery, magic links, MFA, passkeys.
- A Google refresh token, Google offline access, or a Google Sign-In SDK in the client.
- An admin web UI.
- Replacing this issuer with another OIDC provider. A later subject can map onto the same `users.id`. v1 does not build that.
- Hosting vendor selection. That is [CES-86](https://linear.app/personal-interests-llc/issue/CES-86).
