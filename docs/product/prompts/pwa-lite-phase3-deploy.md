# Cursor execution prompt — PWA-lite Phase 2b (deploy + install)

> **Prerequisite:** Phase 1+2 merged to `main` (PR #3 `d10c115`, PR #4 `8c1f1a8`). Do **not** re-implement offline shell or sync client.

**Branch:** cut `feat/pwa-lite-deploy` from `main`
**Spec:** [`docs/specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md) §6 (PWA/manifest) + Phase 2b row in phases table
**Linear:** [CES-62](https://linear.app/personal-interests-llc/issue/CES-62) (parent) — deploy child issue when created

## Goal

Ship a **Cloudflare Pages preview** of `client/web-lite/` so iPhone users can Add to Home Screen and run the **already-built** offline Log + History + sync flow against a reachable API (dev stub tunnel or staging URL).

## Scope (in)

1. **Deploy** `client/web-lite/` to Cloudflare Pages (`wrangler pages deploy` or GitHub Action on `client/web-lite/**`).
2. **`CESTOVNI_API_BASE` runtime config** — today hardcoded in `client/web-lite/sync.js`; expose via one of:
   - build-time injection (small `config.js` generated in CI), or
   - `?api_base=` query bootstrap (mirror `?token=`), documented for preview only.
3. **Stub reachability** — document how preview origin calls the API (Cloudflare Tunnel to local stub, deployed stub Worker, or staging). CORS already on `server/dev-sync-stub/server.js`.
4. **Finalize [`install-ios.md`](../install-ios.md)** — real preview URL, Safari steps, token bootstrap (`?token=dev-cestovni-token` for dev).
5. **Optional CI job** — deploy preview on PR touching `client/web-lite/**` (minute discipline: paths-filter only).

## Scope (out)

- Production CES-43 backend (Postgres, JWT/OIDC, RLS) — separate track
- CES-45 dead-letter UX beyond existing ERROR pill
- Self-hosted woff2 fonts (still fallback stacks; see `client/web-lite/fonts/README.md`)
- Receipt photos (Phase 3 per spec)
- Flutter / `client/lib/` changes

## Constraints

- No COOP/COEP in `client/web-lite/_headers` (iOS offline regression).
- Service worker cache bump only if shell assets change.
- Remove or gate **dev bearer fallback** in `sync.js#getToken()` before any public non-dev URL ships (or document preview-only).
- CI gates unchanged: `client-test` + `telemetry-gate` must stay green.

## Likely touchpoints

- `client/web-lite/sync.js` — `CESTOVNI_API_BASE` config surface
- `client/web-lite/_headers` — verify Pages headers
- `.github/workflows/` — optional `pages-deploy` job (paths-filter)
- `docs/product/install-ios.md`
- `server/dev-sync-stub/README.md` — preview + tunnel notes
- `docs/specs/pwa-lite-v1.md` — Phase 2b status when done

## Existing decisions

- Default local dev: `http://127.0.0.1:8787`, bearer `dev-cestovni-token`, `localStorage` key `cestovni_token`.
- API paths: `POST /api/v1/mutations`, `GET /api/v1/changes?table=&since=&limit=`.
- SW precache: `cestovni-lite-v2` includes `sync.js`.
- Reference gate IDs: `row_id=2ed68a63-2347-4813-9d6e-f903426fa705`, `mutation_id=3b7cea29-7e59-4d11-8842-fe563149b9bf`.

## Acceptance criteria

- [ ] Preview URL loads shell offline after first visit (SW registered)
- [ ] `?token=` + configured API base → save fill-up → pill `SYNCED` (stub or staging reachable from phone)
- [ ] `install-ios.md` has copy-paste URL + steps (no TBD placeholders)
- [ ] Document how product runs iPhone T1 (airplane mode) against preview
- [ ] No secrets committed; preview token documented as dev-only

## Validation

```bash
# Local sanity (unchanged)
node server/dev-sync-stub/server.js
cd client/web-lite && python3 -m http.server 8000
node server/dev-sync-stub/contract.test.js

# After deploy
curl -fsS https://<preview-host>/healthz   # if health proxied; else curl manifest.json
```

## References

- Phase 1+2 status: [`pwa-lite-phase1-2.md`](pwa-lite-phase1-2.md) §Phase 2 status — filled
- Gate: [`docs/specs/pwa-lite-gate.md`](../../specs/pwa-lite-gate.md)
- Delivery plan: [`delivery-plan-v1.md`](../delivery-plan-v1.md) § M-dist

Tag: `Phase 2b — PWA-lite deploy`.
