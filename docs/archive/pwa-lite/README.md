# Archive: iPhone PWA-lite (retired 2026-11-05)

**Verdict:** Retired. This is not the Cestovni web client and it will not be resumed.

**What it was:** A vanilla HTML + IndexedDB capture app for iPhone (Log + History only), built after the Flutter web offline spike failed. Phase 1+2 landed on `main` (PR #3, PR #4). Install-doc and iPhone device testing were never finished.

**Where the code stays:** `client/web-lite/` is frozen in place so old links and the Pages workflow path still resolve. Do not add screens, sync behavior, or portal features there. Automatic Cloudflare deploys are off (manual `workflow_dispatch` only).

**Linear:** [CES-62](https://linear.app/personal-interests-llc/issue/CES-62) and [CES-63](https://linear.app/personal-interests-llc/issue/CES-63) are Canceled.

**Forward path:** Phone-browser portal in [ADR 006](../../specs/adr/006-browser-client.md) (Preact + TypeScript, new `portal/` package). Screens stay blocked until [CES-74](https://linear.app/personal-interests-llc/issue/CES-74) is Done. Gate: [`../../specs/portal-readiness.md`](../../specs/portal-readiness.md).

| Historical doc | What it recorded |
| --- | --- |
| [`../../specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md) | Implementation spec |
| [`../../specs/pwa-lite-gate.md`](../../specs/pwa-lite-gate.md) | Android E2E gate before iPhone work |
| [`../../specs/adr/005-addendum-pwa-lite-ios.md`](../../specs/adr/005-addendum-pwa-lite-ios.md) | ADR addendum (decision record; status Retired) |
| [`../../product/install-ios.md`](../../product/install-ios.md) | Draft install notes, never finalized |
| [`../../product/pwa-lite-deploy-runbook.md`](../../product/pwa-lite-deploy-runbook.md) | Cloudflare Pages runbook |
| [`../../product/prompts/pwa-lite-discovery.md`](../../product/prompts/pwa-lite-discovery.md) | Discovery prompt |
| [`../../product/prompts/pwa-lite-phase1-2.md`](../../product/prompts/pwa-lite-phase1-2.md) | Phase 1+2 execution prompt (complete) |
| [`../../product/prompts/pwa-lite-phase3-deploy.md`](../../product/prompts/pwa-lite-phase3-deploy.md) | Deploy prompt (will not be run) |
| [`../../product/prompts/pwa-lite-phase3-install-doc.md`](../../product/prompts/pwa-lite-phase3-install-doc.md) | Install-doc prompt (will not be run) |

`https://cestovni-pwa.pages.dev` may still serve an old build until the Cloudflare project `cestovni-pwa` is deleted.
