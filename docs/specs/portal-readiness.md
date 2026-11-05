# Portal readiness

**Status:** Open. Portal screens do not start until [CES-74](https://linear.app/personal-interests-llc/issue/CES-74) is Done.
**Milestone:** Web client readiness (Linear project Cestovni).
**Decision:** [ADR 006](adr/006-browser-client.md) Accepted. Stack is Preact + TypeScript. Package will be `portal/`, which does not exist yet.

iPhone PWA-lite is retired. See [`../archive/pwa-lite/README.md`](../archive/pwa-lite/README.md). Do not extend `client/web-lite/`.

## Order

1. **Done in repo (2026-11-05).** PWA-lite docs, Linear CES-62 / CES-63, and the Pages workflow are marked retired. Code stays frozen at `client/web-lite/`.
2. **Answer on CES-74 (not separate tickets).** Three small decisions. Portal screens wait on the answers.
3. **[CES-75](https://linear.app/personal-interests-llc/issue/CES-75).** TypeScript consumption math matches `tests/math/fixtures/`. This is the only `portal/` code allowed before CES-74 is Done. No screens in that change.
4. **Then** open a portal implementation issue (Log, History, vehicles, settings, signed-in sync). Not before.

## Locked already

These are accepted constraints. They are not open issues.

| Risk | Lock |
| --- | --- |
| Offline fill-up in the browser | Out. ADR 006. The retired PWA was the offline iPhone experiment. Flutter web as an installed offline iPhone app stays NO-GO. |
| Android and the portal both editing one account | v1 restore: the server row wins (ADR 002). Live field merge is v1.x. |
| Building the portal inside `client/web-lite/` | Forbidden. New package `portal/`. |
| Metrics, maintenance, photos, ZIP | Out of portal v1 (ADR 006 matrix). |

## Waiting on a product answer

Record the answer on CES-74. Do not open another ticket unless the answer is the large option.

1. **Token.** `server/api` verifies an HS256 JWT and has no user table. A checked-in script that mints a token for a chosen UUID is enough for a developer to call the API. An account system (email, password, or OIDC) is a separate project. Which is required before portal screens? GitHub issue: `https://github.com/JMNofziger/cestovni/issues/37`.
2. **Settings row id.** Android bootstrap still inserts `settings` with a random UUID. The server requires that id to equal the JWT subject, so the first upload is rejected until a restore replaces the row. On first successful auth, rewrite the local row id to the subject, or refuse to create the row until a subject exists? GitHub issue: `https://github.com/JMNofziger/cestovni/issues/38`.
3. **Where the API runs during portal development.** Local `server/api` on the developer machine, or a hosted staging URL first?

## Build blocker

[CES-75](https://linear.app/personal-interests-llc/issue/CES-75) blocks CES-74. Copying economy formulas by eye is the failure that issue exists to prevent. Spec: [`consumption-math.md`](consumption-math.md). Fixtures: `tests/math/fixtures/`.

## Explicitly not this gate

Telemetry (CES-46), Android APK (CES-68), migration rollback (CES-47), the 429 banner, the Android dead-letter edit bug, promotion gates, device timing, and a live Postgres restore test. They stay on their own issues. They do not block portal screens.
