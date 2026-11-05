# Portal readiness

**Status:** Open. Portal screens do not start until [CES-74](https://linear.app/personal-interests-llc/issue/CES-74) is Done.
**Milestone:** Web client readiness (Linear project Cestovni).
**Decision:** [ADR 006](adr/006-browser-client.md) Accepted. Stack is Preact + TypeScript. Package will be `portal/`, which does not exist yet.

iPhone PWA-lite is retired. See [`../archive/pwa-lite/README.md`](../archive/pwa-lite/README.md). Do not extend `client/web-lite/`.

## Order

Each issue blocks the next. Do them in this order.

1. **[CES-76](https://linear.app/personal-interests-llc/issue/CES-76).** Mint an HS256 bearer for a chosen user id. `server/api` already verifies tokens and does not issue them. No sign-in screen in this issue.
2. **[CES-77](https://linear.app/personal-interests-llc/issue/CES-77).** Blocked by CES-76. A settings upload must use that JWT subject as the row id. Android still inserts a random id and the server rejects it.
3. **[CES-78](https://linear.app/personal-interests-llc/issue/CES-78).** Blocked by CES-77. Document local `server/api` (`npm start` in `server/api/`) as the portal dev target, including the mint command. A public host is not required.
4. **[CES-75](https://linear.app/personal-interests-llc/issue/CES-75).** Blocked by CES-78. TypeScript consumption math matches `tests/math/fixtures/`. Library only. No screens.
5. **[CES-74](https://linear.app/personal-interests-llc/issue/CES-74).** Blocked by the four above. When it is Done, open a separate portal implementation issue.

PWA-lite retirement is already done. It is not a step in this list.

## Locked already

These are accepted constraints. They are not open issues.

| Risk | Lock |
| --- | --- |
| Offline fill-up in the browser | Out. ADR 006. Flutter web as an installed offline iPhone app stays NO-GO. |
| Android and the portal both editing one account | v1 restore: the server row wins (ADR 002). Live field merge is v1.x. |
| Building the portal inside `client/web-lite/` | Forbidden. New package `portal/`. |
| Metrics, maintenance, photos, ZIP | Out of portal v1 (ADR 006 matrix). |
| Human sign-in screen | Later. GitHub `https://github.com/JMNofziger/cestovni/issues/37` is not this gate. CES-76 is the mint script. |
| Hosted staging API | Later. CES-78 keeps development on local `server/api`. |

## Explicitly not this gate

Telemetry (CES-46), Android APK (CES-68), migration rollback (CES-47), the 429 banner, the Android dead-letter edit bug, promotion gates, device timing, and a live Postgres restore test. They do not block portal screens.
