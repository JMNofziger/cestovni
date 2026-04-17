# Spec: Platform compliance & privacy posture (v1)

**Status:** Complete (v1) — engineering posture and copy source; **not** legal advice. Counsel drafts the privacy policy and store contracts.

**Linear:** CES-8 (Stage 4 / Phase 2c)

**Workflow:** [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md)

**Canonical technical specs:** [`ARCHITECTURE.md`](ARCHITECTURE.md), [ADR 001](adr/001-backend-api-boundary.md), [ADR 002](adr/002-backup-sync-layer.md), [`data-model.md`](data-model.md), [`sync-protocol.md`](sync-protocol.md), [`export-v1.md`](export-v1.md), [`photo-pipeline.md`](photo-pipeline.md), [`telemetry-allowlist.md`](telemetry-allowlist.md), [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml)

**Launch copy (store / policy skeletons):** [`../product/launch-copy-v1.md`](../product/launch-copy-v1.md)

---

## 1. System recap (one screen)

| Layer | What it holds | User expectation |
| ----- | ------------- | ---------------- |
| **Device** | SQLite: vehicles, fill-ups, maintenance, settings, drafts, outbox, `photo_refs`. Filesystem: JPEG receipt aids under app sandbox `photos/`. | Works offline. Receipt photos stay on this device. |
| **Managed / self-host server** | Postgres: same logical rows as backup target (RLS-scoped per `user_id`). No photo bytes. | Signed-in backup/restore of **structured** history only. |
| **Telemetry pipeline** | Crash + minimal reliability/product events per allow-list; properties bounded in YAML. | No ads, no behavioral surplus; categories declared to Apple/Google. |

---

## 2. Data inventory

Use this table for **App Store privacy labels**, **Play Data safety**, and **privacy policy** data inventory sections.

| Category | Examples | Where stored | In cloud backup? | In ZIP export? |
| -------- | -------- | ------------ | ------------------ | -------------- |
| **Account / identity** | Auth subject (`user_id`), session | Server + client token | Yes (server maps account to rows) | No (export uses `user_key_hash` fragment per [`export-v1.md`](export-v1.md), not raw id) |
| **Vehicle profile** | Name, make, model, year, optional **VIN**, fuel type, tank hint | Client + server when synced | Yes | Yes (`vehicles.csv`) |
| **Fuel & maintenance** | Fill-ups (time, odometer, volume, price, currency, flags, notes), maintenance rules/events | Client + server | Yes | Yes (CSVs per [`export-v1.md`](export-v1.md)) |
| **Preferences** | Units, default currency, timezone | Client + server | Yes | Yes (`settings.csv`) |
| **Receipt photos** | JPEG bytes, `photo_refs` metadata | **Client only** | **No** | **No** — `manifest.json.photos_in_export === false` always ([`photo-pipeline.md`](photo-pipeline.md), [`export-v1.md`](export-v1.md)) |
| **Drafts / outbox** | In-progress rows, pending mutations | Client only | No | No |
| **Telemetry** | Allow-listed events; hashed user key; no raw VIN/notes in events | Vendor + our retention | Partial (vendor config scrubs IP per telemetry spec) | N/A |

**EXIF / location:** Capture pipeline **strips** GPS and sensitive maker tags before persisting JPEG; only derived capture time (UTC) is kept in metadata ([`photo-pipeline.md`](photo-pipeline.md)). Until strip completes in memory, treat camera buffer as sensitive.

---

## 3. User-visible honesty (copy-ready)

Reuse verbatim (or translate) in App Store description, in-app **Settings → Data & privacy**, and first-run hints. Longer rationale lives in linked specs.

1. **Receipt photos** are saved **only on this device** to help you finish a fill-up later. They are **not uploaded** to our servers and **cannot be restored** from backup or another phone.
2. **Cloud backup** (when you are signed in) covers your **fuel and maintenance history** (structured data), not receipt photos.
3. **Export** produces a ZIP of spreadsheets and a manifest for **structured** data only; it **does not include** receipt images ([`export-v1.md`](export-v1.md)).
4. **Telemetry** is limited to crashes and core reliability signals listed in our allow-list; we do **not** sell data or run ads ([`telemetry-allowlist.md`](telemetry-allowlist.md), [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md)).

---

## 4. Export & portability

- **Mechanism:** On-device ZIP per [`export-v1.md`](export-v1.md) — `manifest.json`, `README_export.txt`, per-entity CSVs.
- **Scope:** `vehicles`, `fill_ups`, `maintenance_rules`, `maintenance_events`, `settings` for the signed-in user.
- **Explicit exclusions:** Receipt photos, `drafts`, `outbox`, client logs.
- **Re-import:** No in-app re-import in v1; portability is via open CSV + manifest for user-chosen tools.

---

## 5. Deletion, retention, and erasure

### 5.1 Structured data (client + server)

- **Soft delete:** Backed-up rows use `deleted_at` per [`data-model.md`](data-model.md); sync protocol propagates tombstones ([`sync-protocol.md`](sync-protocol.md)).
- **Account deletion (v1 posture):** When the user deletes their account (or requests erasure), the product **removes or irreversibly tombstones** all server-side rows for that `user_id` under RLS ([ADR 001](adr/001-backend-api-boundary.md)). Exact API surface and operator runbook steps ship with implementation; this doc locks the **user-facing promise**: no retained structured history after successful account deletion.
- **Local wipe:** Uninstalling the app or OS “clear data” removes local SQLite and sandbox photos; remind users to **export first** if they need a copy.

### 5.2 Receipt photos

- User delete on draft/fill-up: **immediate** file + row removal ([`photo-pipeline.md`](photo-pipeline.md)).
- Automatic TTL: **30 days from capture** or **7 days after fill-up completion**, whichever is sooner.

### 5.3 Telemetry and the user key (right-to-erasure alignment)

Per [`telemetry-allowlist.md`](telemetry-allowlist.md):

- Events use a **peppered HMAC** of `user_id` as the stable telemetry key, not the raw account id in payloads.
- **v1 engineering rule:** On account deletion (or a dedicated “reset telemetry link” product decision), the server **deletes the pepper row** for that user (or rotates global pepper + invalidates old rows per ops playbook). Historical event rows may remain in cold storage but **cannot be correlated** back to the person without the pepper — satisfying the posture described in the telemetry spec. **Retention per event** is capped by `retention_days` in [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml); vendor dashboards inherit those caps.

**CI note:** The telemetry gate script referenced in [`telemetry-allowlist.md`](telemetry-allowlist.md) (`ci/telemetry-gate.*`) is a **Stage 5** implementation item; Stage 4 only locks **categories and process**.

---

## 6. Payments and donations

Aligned with [`PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md):

- Core features remain **fully usable without payment**.
- **Donations / tips** are **optional gratitude** only — never framed as paying for fuel logging or export.
- **Store compliance:** If tips use native IAP where required by platform policy, store listings must say so plainly; product + legal decide SKU copy. No invented pricing or SKU IDs in this repo.

---

## 7. Third parties and SDKs

- **Allowed:** Crash and diagnostics SDKs that respect the allow-list (no automatic enrichment with contacts, location, or ad IDs).
- **Not in v1:** Ad networks, attribution SDKs, social SDKs, behavioral analytics warehouses beyond the allow-list.
- **Self-host:** Same client; operator runs Postgres + API. Privacy policy should mention continuity path per [`self-host-runbook.md`](self-host-runbook.md) when we ship public self-host packages.

---

## 8. Platform disclosures (Apple & Google)

### 8.1 Source of truth

- **Normative category table:** [`telemetry-allowlist.md`](telemetry-allowlist.md) — section **Apple privacy manifest (App Store)**. Any change to declared categories requires **product + engineering** review and an App Store / Play listing update if user-facing claims shift.

### 8.2 Apple — `PrivacyInfo.xcprivacy` (or Flutter-generated equivalent)

| Manifest obligation | v1 handling |
| ------------------- | ----------- |
| **Privacy Nutrition / required-reason APIs** | Declare only APIs the app uses for its stated purpose (e.g. file timestamp, disk space) — fill at implementation time against Apple’s latest reason enum. |
| **Data collection** | Mirror the four rows in the telemetry spec table: Crash Data, Performance Data, Product Interaction, Diagnostics — each **App Functionality** (and **Analytics** only where the spec already marks Product Interaction); **Linked: No**, **Tracking: No** for those rows. |
| **Maintenance owner** | Mobile client team; **when:** any change to [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) or emit sites. |

### 8.3 Google Play — Data safety form

Map **§2 Data inventory** rows to Play categories:

| Inventory row | Typical Play mapping (verify at submit time) |
| ------------- | --------------------------------------------- |
| Vehicle + fill-up + maintenance + settings | **Personal info** (name if typed in vehicle name — treat as user content), **Financial info** (optional: price fields — many jurisdictions treat purchase history as financial; declare if Play questionnaire requires). |
| Optional VIN | **Personal info** — user-provided identifier. |
| Receipt photos | **Photos** — **not collected** by developer server (stored on device only); answer form accordingly (“collected” only if Google defines on-device as in scope — follow current Play Console definitions at submission). |
| Telemetry allow-list | **App activity** (diagnostics/crash) per questionnaire; **not used for advertising**. |

**Process:** When YAML or manifest changes, update **both** Apple manifest and Play form in the **same release train**.

---

## 9. Data residency and minors (v1 position)

| Topic | v1 position |
| ----- | ----------- |
| **Data residency** | No **user-selectable** region in v1. Managed Postgres runs in the operator’s chosen cloud region (document region in managed runbook / customer FAQ when live). **Self-host** lets technical users choose jurisdiction. EU/UK DPA and SCC stack are **operator legal** tasks before EU marketing claims. |
| **Minors / COPPA** | v1 is **not directed at children**; no age gate in v1. If analytics ever suggests under-13 signups, product must add gating or counsel review before scaling marketing to schools/families. |

---

## 10. Service cessation & continuity

- Users can **export** structured history any time ([`export-v1.md`](export-v1.md)).
- **Managed service discontinuation:** communicate notice period + final export window + pointer to **self-host** continuity per brief and [`self-host-runbook.md`](self-host-runbook.md).
- **Photos:** unchanged — never on server; cessation does not create photo loss beyond normal device loss (already communicated in §3).

---

## 11. Engineering sign-off checklist (Stage 4 exit)

- [ ] Data inventory rows match [`data-model.md`](data-model.md) backed-up tables + client-only tables.
- [ ] Photo + export claims match [`photo-pipeline.md`](photo-pipeline.md) and [`export-v1.md`](export-v1.md).
- [ ] Backup scope matches [ADR 002](adr/002-backup-sync-layer.md) + [`sync-protocol.md`](sync-protocol.md).
- [ ] Telemetry claims match [`telemetry-allowlist.md`](telemetry-allowlist.md) + YAML.
- [ ] [`../product/launch-copy-v1.md`](../product/launch-copy-v1.md) reuses §3 bullets without contradiction.

When all boxes are checked in PR or Linear **CES-8**, Stage 4 is **closed** from an engineering posture perspective.
