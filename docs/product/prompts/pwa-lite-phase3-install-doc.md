# Cursor execution prompt — PWA-lite Phase 2b (install doc + status close-out)

> **Prerequisite:** Phase 1+2 on `main` (PR #3 `d10c115`, PR #4 `8c1f1a8`). Phase 2b runtime config (PR #5 `88e4571`) and Cloudflare Pages deploy workflow (PR #6 `3d17342`) **merged**; Cloudflare secrets/project status confirmed (PR #7 `4aa7e88`). **Production deploy is now actually live:** `https://cestovni-pwa.pages.dev` (manually triggered via `workflow_dispatch` on `main` 2026-06-30 22:5x — confirm it's still 200 before citing it; see "deploy-trigger gap" below).

## Goal

Close out PWA-lite Phase 2b: finalize `docs/product/install-ios.md` with the real production URL and Safari steps, document the iPhone T1 (airplane mode) test procedure, and flip the cross-cutting status docs from "Next"/"Draft" to "Done".

## Context (already done — do not re-implement)

- `feat/pwa-lite-api-config` (merged): `client/web-lite/config.js` (`window.CESTOVNI_CONFIG = { apiBase, allowDevTokenFallback }`), `?api_base=`/`?token=` query bootstrap, gated dev-bearer fallback.
- `feat/pwa-lite-pages-ci` (merged): `.github/workflows/pwa-lite-pages-deploy.yml`, `docs/product/pwa-lite-deploy-runbook.md`.
- PR #7 (`4aa7e88`, docs-only): confirmed Cloudflare secrets + `cestovni-pwa` project exist; noted **no preview has had `config.js#apiBase` pointed at a tunnel/staging yet**, so the sync round-trip acceptance criterion is still open — your install doc should reflect this honestly (Log + History work fully offline regardless; sync needs a manual `api_base` override to prove end-to-end).
- **Known gap, not yours to fix:** the deploy workflow's `push`/`pull_request` trigger only fires when the **same commit** touches `client/web-lite/**`. Neither the PR #5 nor PR #6 merge commit re-triggered a `main`/production deploy automatically — production only went live because it was force-triggered via `gh workflow run ... --ref main`. Record this as a runbook note (task #3 below); do not modify the workflow's trigger config.

## Scope (in)

1. **Finalize [`docs/product/install-ios.md`](../install-ios.md)**:
   - Replace the "link TBD" step with `https://cestovni-pwa.pages.dev`.
   - Document the dev/demo bootstrap query params: `?token=dev-cestovni-token` (existing) and `?api_base=<url>` (new) — needed because the production `config.js` still points `apiBase` at `http://127.0.0.1:8787`, unreachable from a real iPhone.
   - Add the **iPhone T1 procedure**: open URL in Safari → Add to Home Screen → toggle Airplane Mode → log a fill-up → toggle Airplane Mode off → confirm pill flips `PENDING` → `SYNCED` (only provable today with a tunnel/staging `api_base` override — say so plainly, don't imply it's proven against production as shipped).
2. **Flip status docs** (you own these three; no other branch touches them):
   - [`docs/specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md) — Phases table row `2b`: `**Next**` → `**Done**`, cite PR #5/#6/#7 + the production URL.
   - [`docs/specs/pwa-lite-gate.md`](../../specs/pwa-lite-gate.md) — "PWA-lite implementation status" table: Phase 2b row `**Next**` → `**Done**`.
   - [`docs/product/delivery-plan-v1.md`](../delivery-plan-v1.md) § M-dist — update PWA-lite line to reflect deploy done; install doc finalized.
3. **Record the deploy-trigger gap** in `docs/product/pwa-lite-deploy-runbook.md` §4 (Verifying a deploy): one note that a docs-only or workflow-only merge to `main` will *not* redeploy production — use `workflow_dispatch` (Actions tab or `gh workflow run pwa-lite-pages-deploy.yml --ref main`) to force one when `client/web-lite/**` itself hasn't changed in the merge commit.

## Scope (out / non-goals)

- `client/web-lite/config.js`, `sync.js`, `index.html`, `sw.js` — owned by `feat/pwa-lite-api-config` (merged). Do not edit.
- `.github/workflows/pwa-lite-pages-deploy.yml` — do not edit the trigger logic itself; the gap is a runbook note only (task #3).
- Per-environment `config.js` override (pointing production `apiBase` at a real API) — a Cloudflare dashboard / ops action, not a Cursor change. Do not set up a permanent tunnel or staging backend.
- Flipping `allowDevTokenFallback: false` — explicitly **not yet**: no production auth (CES-43) exists to fall back to. Do not change this.
- Flutter / `client/lib/` changes. Receipt photos (Phase 3 per spec).

## Constraints

- Docs/markdown only — no code changes in this branch.
- Don't invent a second config mechanism; `?api_base=`/`?token=` query bootstrap is the only documented override path.
- Keep edits scoped to the 4 files in Scope (in); do not touch `client/web-lite/**` or `.github/workflows/**`.
- No Cursor attribution in commits.

## Likely touchpoints (max 4)

- `docs/product/install-ios.md`
- `docs/specs/pwa-lite-v1.md` (Phases table row only)
- `docs/specs/pwa-lite-gate.md` (status table row only)
- `docs/product/delivery-plan-v1.md` (§ M-dist, PWA-lite line only)
- `docs/product/pwa-lite-deploy-runbook.md` (§4, one note — stretch if time allows)

## Existing decisions (authoritative)

- Production URL: `https://cestovni-pwa.pages.dev` (Cloudflare Pages project `cestovni-pwa`).
- Config contract: `window.CESTOVNI_CONFIG = { apiBase, allowDevTokenFallback }` from `client/web-lite/config.js`; `?api_base=`/`?token=` query bootstrap persists to `localStorage` (`cestovni_api_base`, `cestovni_token`).
- Dev bearer: `dev-cestovni-token`, gated by `allowDevTokenFallback` (currently `true` in shipped `config.js` — intentional until CES-43).
- Reference gate IDs (already in `pwa-lite-gate.md`): `row_id=2ed68a63-2347-4813-9d6e-f903426fa705`, `mutation_id=3b7cea29-7e59-4d11-8842-fe563149b9bf`.

## Git / merge workflow

- Branch `feat/pwa-lite-install-doc` from `main` (latest — confirm `main` includes PR #7 `4aa7e88` before cutting).
- Open a PR; enable auto-merge (`gh pr merge --auto --merge`). Do not bypass CI (`client-test`, `telemetry-gate`); confirm `pwa-lite-pages-deploy.yml` does *not* fire (no `client/web-lite/**` changes in this branch).

## Execution Rules

1. Ask at most 3 clarifying questions only if blocked.
2. Implement immediately; keep edits minimal and localized to the touchpoints above.
3. Validate: `curl -fsS https://cestovni-pwa.pages.dev/manifest.json` (confirm still live before citing it); read through `install-ios.md` for zero remaining "TBD" strings.
4. Do not re-run the Flutter suite or trigger a Pages deploy.
5. Return status in the required format only.

## Required Status Format (strict)

### Plan
- <3-5 bullets>

### Changes Made
- `file/path`: <one-line>

### Validation
- Commands run:
  - `<command>`
- Result: <pass/fail + key signal>

### Risks / Follow-ups
- <max 5 bullets>

### Next Smallest Phase
- <single step>
