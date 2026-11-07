# ADR 007: Google sign-in, app-owned sessions

**Status:** Accepted
**Date:** 2026-11-07
**Accepted on:** 2026-11-07
**Amends:** [ADR 001](001-backend-api-boundary.md) deployment-matrix auth row, role table, and the follow-up “Select concrete auth provider mix”
**Linear:** [CES-79](https://linear.app/personal-interests-llc/issue/CES-79), [CES-76](https://linear.app/personal-interests-llc/issue/CES-76)
**Normative contract:** [`../identity-provider.md`](../identity-provider.md)

## Context

The API and the database already share one identity. `settings.id`, every RLS `user_id`, and `app.user_id` are the same UUID. `server/api/src/auth.js` accepts only an HS256 bearer whose `sub` is that UUID.

Nothing issues that token. Android sends a compile-time bearer. HTTP 401 pauses backup and has no way back. There is no `users` table, no sign-in, and no account-deletion endpoint.

The audience is one to five people. Logging on Android must keep working with no network. The same person must reach one backup from the Android app and from the online portal.

Product confirmed on 2026-11-07: **Google is the only sign-in door.**

## Decision

Google proves who the person is. This API proves what the database is allowed to see.

1. The person signs in with a Google account. The client never calls a Google API. It opens a browser step (a Chrome custom tab on Android, a navigation in the portal) against this API, which talks to Google.
2. The API reads Google’s `sub`, stores it on `users.google_sub`, and allocates `users.id` as a UUID the first time that Google subject appears.
3. The API mints its own access token. `sub` is `users.id`. The same Google account on Android and on the web resolves to that same UUID.
4. Android stores this API’s refresh token and uses it for later syncs. Offline logging does not contact Google. A new install needs a network for the first sign-in.
5. Passwords, invites, email delivery, and an operator password reset are not part of v1.
6. The same process and the same claim model run in managed mode and in self-host mode. A self-host operator registers their own Google OAuth client. Sign-in still depends on Google. The Postgres data does not.

Account deletion remains our endpoint. Google does not remove our rows.

## Alternatives

| Option | Verdict | Reason |
| --- | --- | --- |
| Mint script (CES-76 as originally filed) | Rejected | No users, no refresh, no deletion. A token with no `exp` would verify forever under today’s `auth.js`. |
| Email and password, invite codes, operator reset | Rejected 2026-11-07 | Product chose Google as the only sign-in door. [CES-82](https://linear.app/personal-interests-llc/issue/CES-82) is Canceled. |
| Supabase Auth, Auth0, Clerk, Firebase, or Neon Auth as the API issuer | Rejected | Their `sub` is not our UUID. Free tiers pause or cap the account, which would take sign-in and backup down together. |
| Self-hosted Keycloak, GoTrue, or Zitadel | Rejected | A second always-on service. It does not fit one free API instance. |
| Put Google’s `sub` in `app.user_id` | Rejected | It is not a UUID. `auth.js`, the `settings` CHECK, and RLS would reject it. |
| **Google sign-in plus an app-owned session** | **Chosen** | One process, one database, `sub` is our UUID, and both clients share that UUID. |

## What stays true

- ADR 001 client rule: product features call this API only.
- Offline-first logging ([ADR 002](002-backup-sync-layer.md)). The local database stays the source of truth.
- The portal stays online-only ([ADR 006](006-browser-client.md)). Its bearer stays in `sessionStorage`.
- `settings.id` equals `users.id` after sign-in. Android rebinds a bootstrap row ([CES-77](https://linear.app/personal-interests-llc/issue/CES-77)). The portal creates the row with that id.
- No foreign keys from product tables to `users`.

## Consequences

- We verify Google ID tokens and store `google_sub` and email. We do not store a Google refresh token, and we do not request offline access from Google.
- We still own session rotation, logout, and account deletion. That surface is the identity module in `server/api`, specified in [`identity-provider.md`](../identity-provider.md).
- A person with two Google accounts has two backups. The product does not merge them.
- Self-host continuity covers Postgres and this API. It does not cover a world where Google is unreachable. That limit is written in the self-host runbook.
- The exit path, if Google must be replaced later, is a second subject column on `users` pointing at the same UUID. RLS and `settings.id` stay. [CES-88](https://linear.app/personal-interests-llc/issue/CES-88) (replace this issuer with an external OIDC provider) is Canceled. v1 does not build that mapping.

## Roles this decision adds

Created by the identity migration ([CES-80](https://linear.app/personal-interests-llc/issue/CES-80)). They are not in `db/migrations/0001_init.sql`.

| Role | Purpose | Scope |
| --- | --- | --- |
| `cestovni_auth` | Identity tables only | `SELECT`, `INSERT`, `UPDATE`, `DELETE` on `users`, `auth_sessions`, `auth_refresh_tokens`, `auth_oauth_states`, `auth_login_transactions` |
| `cestovni_purge` | Account deletion | `SELECT`, `DELETE` on the five product tables, through existing RLS |

`cestovni_app` receives no grant on identity tables.
