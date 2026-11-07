# Portal readiness

**Status:** Open. Portal screens do not start until [CES-74](https://linear.app/personal-interests-llc/issue/CES-74) is Done.
**Milestone:** Web client readiness (Linear project Cestovni).
**Decision:** [ADR 006](adr/006-browser-client.md) Accepted. Stack is Preact + TypeScript. Package will be `portal/`, which does not exist yet.
**Sign-in:** [ADR 007](adr/007-identity-provider.md) Accepted. Google is the only sign-in door. The contract is [`identity-provider.md`](identity-provider.md). The running API does not implement it yet.

iPhone PWA-lite is retired. See [`../archive/pwa-lite/README.md`](../archive/pwa-lite/README.md). Do not extend `client/web-lite/`.

## Answers recorded (2026-11-07)

These were open questions on this gate. They are closed.

| Question | Answer |
| --- | --- |
| Mint-script token or an account system? ([GitHub #37](https://github.com/JMNofziger/cestovni/issues/37)) | Account system. Google sign-in, then this API's UUID bearer. The mint script is rejected. Android sign-in is [CES-89](https://linear.app/personal-interests-llc/issue/CES-89). |
| Settings row id ([GitHub #38](https://github.com/JMNofziger/cestovni/issues/38)) | On first sign-in, Android rebinds the bootstrap `settings.id` to `users.id` ([CES-77](https://linear.app/personal-interests-llc/issue/CES-77)). If the server already has the row, restore wins. The portal creates `settings` with `id` equal to the session `user_id`. |
| Where the API runs during portal development | Local `server/api`. A hosted URL does not gate portal screens ([CES-78](https://linear.app/personal-interests-llc/issue/CES-78), [CES-86](https://linear.app/personal-interests-llc/issue/CES-86)). |

Passwords, invite codes, and an operator password reset are retired ([CES-82](https://linear.app/personal-interests-llc/issue/CES-82) Canceled). Replacing this issuer with another OIDC provider is retired ([CES-88](https://linear.app/personal-interests-llc/issue/CES-88) Canceled).

## Order

1. **Done in repo (2026-11-05).** PWA-lite docs, Linear CES-62 / CES-63, and the Pages workflow are marked retired. Code stays frozen at `client/web-lite/`.
2. **Done (2026-11-07).** Sign-in decision and this gate's three answers, recorded above. [CES-76](https://linear.app/personal-interests-llc/issue/CES-76) is the design lock.
3. **Identity implementation, in dependency order.** [CES-80](https://linear.app/personal-interests-llc/issue/CES-80) schema, [CES-81](https://linear.app/personal-interests-llc/issue/CES-81) session library, [CES-83](https://linear.app/personal-interests-llc/issue/CES-83) Google auth endpoints, [CES-84](https://linear.app/personal-interests-llc/issue/CES-84) verifier cutover.
4. **[CES-78](https://linear.app/personal-interests-llc/issue/CES-78).** Document the local Google sign-in loop for portal development. Blocked by CES-84.
5. **[CES-75](https://linear.app/personal-interests-llc/issue/CES-75).** TypeScript consumption math matches `tests/math/fixtures/`. Parallel with identity. This is the only `portal/` code allowed before CES-74 is Done. No screens in that change.
6. **Then** open a portal implementation issue (Log, History, vehicles, settings, signed-in sync). Not before.

## Locked already

These are accepted constraints. They are not open issues.

| Risk | Lock |
| --- | --- |
| Offline fill-up in the browser | Out. ADR 006. The retired PWA was the offline iPhone experiment. Flutter web as an installed offline iPhone app stays NO-GO. |
| Android and the portal both editing one account | Same Google account is one `users.id`. v1 restore: the server row wins (ADR 002). Live field merge is v1.x. |
| Building the portal inside `client/web-lite/` | Forbidden. New package `portal/`. |
| Metrics, maintenance, photos, ZIP | Out of portal v1 (ADR 006 matrix). |
| Password or invite sign-up | Out. ADR 007. |

## Build blocker

[CES-75](https://linear.app/personal-interests-llc/issue/CES-75) blocks CES-74. Copying economy formulas by eye is the failure that issue exists to prevent. Spec: [`consumption-math.md`](consumption-math.md). Fixtures: `tests/math/fixtures/`.

[CES-76](https://linear.app/personal-interests-llc/issue/CES-76), [CES-84](https://linear.app/personal-interests-llc/issue/CES-84), and [CES-78](https://linear.app/personal-interests-llc/issue/CES-78) also block CES-74.

## Explicitly not this gate

Android settings rebind (CES-77), Android session and sign-in (CES-87, CES-89), account deletion (CES-85), and free-tier staging (CES-86). They gate Android backup and public launch.

Telemetry (CES-46), Android APK (CES-68), migration rollback (CES-47), the 429 banner, the Android dead-letter edit bug, promotion gates, device timing, and a live Postgres restore test. They stay on their own issues. They do not block portal screens.
