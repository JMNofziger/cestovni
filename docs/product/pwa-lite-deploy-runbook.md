# PWA-lite deploy runbook (Cloudflare Pages)

> Covers manual/local deploys of `client/web-lite/` and how to point a
> deployed preview at a reachable API. Automated CI deploy:
> [`.github/workflows/pwa-lite-pages-deploy.yml`](../../.github/workflows/pwa-lite-pages-deploy.yml)
> (triggers on `push`/`pull_request` touching `client/web-lite/**`).

## 1. Required accounts / secrets

| Name | Where used | Notes |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | CI secret + local env | Cloudflare dashboard → **My Profile → API Tokens** → create token with **Cloudflare Pages: Edit** permission for the account. |
| `CLOUDFLARE_ACCOUNT_ID` | CI secret + local env | Cloudflare dashboard → right sidebar of any zone/account overview page. |
| Cloudflare Pages project `cestovni-pwa` | created once via dashboard or `wrangler pages project create cestovni-pwa` | Same project name used by CI and the existing manual command in `docs/product/prompts/pwa-lite-phase1-2.md`. |

Set the two secrets in **GitHub → Settings → Secrets and variables → Actions**
for this repo so `pwa-lite-pages-deploy.yml` can run. Never commit them.

> **Status (2026-06-30):** `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` are
> configured as repo secrets and the `cestovni-pwa` Pages project already
> exists. CI deploy verified green; preview reachable
> (`https://feat-pwa-lite-pages-ci.cestovni-pwa.pages.dev` at merge time —
> branch alias, will differ per branch). If either is ever missing/rotated,
> recreate per the table above — the Action fails fast with a clear
> "not logged in" or "project not found" error rather than hanging.

## 2. Manual deploy (local)

```bash
# one-time auth (opens browser) — or export CLOUDFLARE_API_TOKEN instead
wrangler login

# from repo root
wrangler pages deploy client/web-lite --project-name cestovni-pwa
```

- Omit `--branch` to let Wrangler infer it from the current git branch
  (non-`main` branches deploy as a **preview**; `main` deploys to
  **production**).
- The command prints the deployment URL (preview: `https://<hash>.cestovni-pwa.pages.dev`;
  production: `https://cestovni-pwa.pages.dev`).
- No build step — `client/web-lite/` is uploaded as static assets as-is.

## 3. Pointing the preview at a reachable API

The client reads `window.CESTOVNI_CONFIG.apiBase` from `client/web-lite/config.js`
(loaded before `app.js` in `index.html`; owned by `feat/pwa-lite-api-config`).
To make a deployed preview talk to a real API, **edit/regenerate `config.js`
before deploying** — do not invent a second config mechanism (e.g. query
params or hardcoded URLs in `sync.js`).

Two ways to get a reachable API for a preview:

### Option A — Cloudflare Tunnel to a local dev stub

Run the existing zero-dependency stub and expose it publicly:

```bash
# terminal 1
cd server/dev-sync-stub && node server.js   # http://127.0.0.1:8787

# terminal 2 — requires `cloudflared` installed
cloudflared tunnel --url http://127.0.0.1:8787
```

`cloudflared` prints a `https://<random>.trycloudflare.com` URL. Set that as
`apiBase` in `config.js`, then deploy. CORS is already permissive on the stub
for Pages preview origins (`server/dev-sync-stub/server.js`).

Caveats: the tunnel only stays up while your machine + `cloudflared` process
are running, and the random URL changes every run — fine for ad hoc product
review, not for a stable demo link.

### Option B — Staging URL

If a longer-lived API endpoint exists (e.g. a deployed dev-stub Worker or
early staging backend), set `apiBase` in `config.js` to that URL instead.
There is no staging backend stood up by this branch — production backend
work is tracked separately (CES-43) and out of scope here.

### Auth token for either option

Bearer `dev-cestovni-token` (dev-only; see `server/dev-sync-stub/README.md`).
Set via `localStorage` key `cestovni_token` in the deployed app, or the
`?token=dev-cestovni-token` URL bootstrap.

## 4. Verifying a deploy

```bash
curl -fsS https://<preview-or-prod-host>/manifest.json   # static asset reachable
```

Then open the URL in a browser: service worker should register, and (with a
reachable `apiBase` + token per §3) saving a fill-up should flip the sync
pill from `PENDING` to `SYNCED`.

## 5. Rollback

Cloudflare Pages keeps deployment history per project. To roll back:

```bash
wrangler pages deployment list --project-name cestovni-pwa
```

Then promote a previous deployment to production from the Cloudflare
dashboard (**Workers & Pages → cestovni-pwa → Deployments → ⋯ → Rollback to
this deployment**) — Wrangler CLI does not currently expose a rollback
subcommand.
