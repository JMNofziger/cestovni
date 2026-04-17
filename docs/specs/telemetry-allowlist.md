# Spec: Telemetry allow-list & crash reporting

**Status:** Complete (v1)
**Linear:** CES-29
**Depends on:** [`photo-pipeline.md`](photo-pipeline.md) (emits `photo_capture`), [`sync-protocol.md`](sync-protocol.md) (emits sync/restore events), [`export-v1.md`](export-v1.md) (emits export events)
**Machine-readable companion:** [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml)

## Purpose

Define exactly which telemetry and crash data the app is allowed to emit, the rules that keep it honest, and the CI gate that prevents drift. **Minimal** is a product principle, not a wish list.

## Principles (from the product brief)

1. **Reliability and honest product improvement only.** No behavioral surplus for ads, no monetization stacks, no third-party resale of user data.
2. **Opt-out available**: Settings → Privacy → "Send anonymous diagnostics" toggle; default **on** for crashes, **on** for sync/export result events (needed to debug user-reported bugs), **off** for everything else. Revisiting defaults after launch is a product decision, not an engineering one.
3. **Hashed user identity only.** The app derives a stable telemetry key from the user's account id using HMAC-SHA-256 with a server-provided pepper; the raw user id never leaves the device.
4. **No free-text fields.** No user-entered strings (notes, names, VINs) are ever telemetry properties.
5. **Allow-list or drop.** If an event is not in [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml), the client refuses to emit it and the CI gate fails the build.
6. **Versioned.** The allow-list file name carries the schema version (`v1`); changes require a PR review and a matching file rename for breaking changes.

## v1 event catalogue (authoritative list)

The file [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) is the source of truth. The table below summarizes what's in v1 for human reading.

| Event name              | Category    | Why we need it                                                   | Retention |
| ----------------------- | ----------- | ---------------------------------------------------------------- | --------- |
| `app_start`             | reliability | Funnel denominator for crash-free sessions.                      | 30 days   |
| `app_crash`             | crash       | Fix crashes. Includes symbolicated stack + SDK breadcrumbs only. | 90 days   |
| `sync_backup_attempt`   | reliability | Denominator for backup success rate.                              | 30 days   |
| `sync_backup_result`    | reliability | Success/fail + error code; catch regressions in real traffic.   | 30 days   |
| `restore_start`         | reliability | Detect stuck or very-long restores.                                | 30 days   |
| `restore_result`        | reliability | Restore success rate; time-to-usable.                              | 30 days   |
| `export_start`          | reliability | Denominator for export success.                                    | 30 days   |
| `export_result`         | reliability | Catch export regressions (size, duration, outcome).                | 30 days   |
| `fill_up_complete`      | product     | Core funnel heartbeat; confirms math surface is reachable.         | 30 days   |
| `vehicle_add`           | product     | First-vehicle onboarding funnel completion.                        | 30 days   |
| `photo_capture`         | product     | Confirm camera permission and capture flow work across platforms.  | 30 days   |

**Properties** for each event (typed, bounded cardinality) live in the YAML. Free-form strings, PII fields, and high-cardinality values (email, VIN, filenames) are **banned** at schema-validation time.

## PII classification

Every property in [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) carries a `pii_class`:

| Class       | Examples                                                        | Allowed in telemetry |
| ----------- | --------------------------------------------------------------- | -------------------- |
| `none`      | enum values, booleans, bucketed durations, app version, OS      | Yes                  |
| `pseudo`    | hashed user key, hashed device id                               | Yes, with context    |
| `identifier`| raw user id, email, VIN, odometer, fuel volume, license plate   | **Never**            |
| `freetext`  | notes, names, vehicle display names                             | **Never**            |

CI rejects any `pii_class: identifier` or `pii_class: freetext` present in the allow-list.

## Transport + SDK

- **Crashes:** **Sentry (self-host-capable)** per [ADR 004](adr/004-telemetry-crash-sdk.md). The SDK MUST support:
  - Server-side PII scrub configuration (URL, IP, body) committed to infra repo (not to client).
  - Breadcrumb allow-list (see below).
  - Deterministic release tagging so crashes map to Git SHAs.
  - A self-hostable or region-pinnable option is preferred for the continuity promise in ADR 001; if not available, document as a managed-only dependency in `docs/specs/ARCHITECTURE.md`.
- **Product events:** either the same SDK's event API or a minimal in-house HTTPS endpoint on the app-owned contract. No third-party product analytics SDKs (Mixpanel, Amplitude, Segment, Rudderstack, etc.) in v1.

## Breadcrumb allow-list

Crash breadcrumbs are free-form by default in every SDK; we constrain them:

- **Allowed categories:** `navigation`, `network` (URL host + status code only, no paths or bodies), `lifecycle`, `user_action` (from a fixed enum).
- **Banned:** `console`, `log`, `info` dumps that capture arbitrary strings; any `data` payload that echoes user input.
- Implementation: a single `sanitizeBreadcrumb(crumb)` function in the client is called by the SDK beforeSend hook; it drops any crumb whose category is not on the list and strips properties that aren't enum/bool/int.

## PII scrub pipeline

Applied to every crash payload and every product event before transmission:

1. **Drop** all properties whose key is not listed in the allow-list for that event name.
2. **Drop** any property whose value is a string longer than 64 bytes (precaution; crash SDKs sometimes include message bodies).
3. **Replace** device identifiers with the hashed user key.
4. **Scrub** URL paths in the network breadcrumb category to host + status only.
5. **Strip** IP addresses server-side (SDK config) as a second line of defense.

## Apple privacy manifest (App Store)

v1 manifest declares exactly:

| Data category        | Purpose                          | Linked to user | Tracked |
| -------------------- | -------------------------------- | -------------- | ------- |
| Crash Data           | App Functionality                | No             | No      |
| Performance Data     | App Functionality                | No             | No      |
| Product Interaction  | App Functionality, Analytics     | No             | No      |
| Diagnostics          | App Functionality                | No             | No      |

We do **not** declare identifiers, contacts, financial info, location, search history, or browsing history. A CI check compares the allow-list YAML to the manifest and fails on drift.

## Right-to-erasure alignment

Because the user's telemetry key is a **pepper-HMAC** of the user id, server-side deletion of the pepper (or its rotation) renders historical telemetry rows un-correlatable to the user without touching them row-by-row. The full plan — including the pepper lifecycle and per-user deletion — is finalized in [`platform-compliance-v1.md`](platform-compliance-v1.md) (Stage 4).

## CI gate

A script at `ci/telemetry-gate.*` runs on every PR:

1. Parses [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml).
2. Static-analyzes client code for calls to the telemetry emit function; every `eventName` literal MUST match an entry in the YAML. Unknown names fail the build.
3. Validates the YAML against a JSON Schema (`ci/telemetry-schema.json`) that enforces the property typing, `pii_class`, retention, and banned classes.
4. Compares YAML category totals to the Apple privacy manifest and fails on drift.

Runtime fallback: the client's emit function also consults the compiled-in allow-list and **silently drops** unknown events with a single local log line (no network call). CI is the primary gate; runtime drop is a last line of defense.

## Companion YAML — shape

See [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) for the full file. Each entry:

```yaml
- name: sync_backup_result
  category: reliability
  retention_days: 30
  properties:
    - name: outcome
      type: enum
      values: [ok, retriable_error, non_retriable_error]
      pii_class: none
    - name: duration_ms_bucket
      type: enum
      values: [lt_500, lt_2000, lt_10000, ge_10000]
      pii_class: none
    - name: error_code
      type: enum
      values: [conflict, unauthorized, rate_limited, network, server_5xx, client_4xx, unknown]
      pii_class: none
```

## Non-goals (v1)

- **User-level analytics dashboards** (cohorts, retention funnels) — not built; data would be insufficient by design.
- **A/B testing infrastructure** — not built.
- **Real-user performance monitoring** beyond crashes + sync/export outcomes.
- **Marketing attribution** — never.

## Critical gaps / risks

- **SDK chosen:** Sentry (self-host-capable) per [ADR 004](adr/004-telemetry-crash-sdk.md). Breadcrumb allow-list enforced via `beforeSend` + `sanitizeBreadcrumb` in the client (wired in Milestone 4 per [`../product/delivery-plan-v1.md`](../product/delivery-plan-v1.md)).
- **Pepper management** for the telemetry key is owned by the platform-compliance spec (Stage 4); this spec assumes it exists.
- **Opt-out default policy** (what is on/off out of the box) is currently engineering's best guess; product may revise before launch.

## References

- [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) — telemetry principles.
- [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) — the authoritative allow-list.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — crash SDK hosting/continuity notes.
- [`platform-compliance-v1.md`](platform-compliance-v1.md) — pepper lifecycle and DSR alignment.
