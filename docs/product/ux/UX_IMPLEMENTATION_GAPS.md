# UX implementation gaps — tracker

**Purpose:** Track documentation and product gaps discovered before M1 UI execution so they do not leak into implementation as silent contradictions.

**Gate:** **CES-39** (Fill-up + vehicle UI) must not move to **In Progress** / implementation until every row under [Critical gaps — Linear blockers](#critical-gaps--linear-blockers) is **Done** and this file’s status column is updated. Dependent M1 work that assumes resolved contracts (shell nav, maintenance forms, metrics tied to maintenance rows) stays behind the same gate.

**Owner:** Product + CTO (engineering owns closure in code/specs).

**Last reviewed:** 2026-04-24 (CES-53, CES-54 done in repo; two blockers remain for CES-39)

---

## Critical gaps — Linear blockers

These are **preconditions for CES-39**. Each has a dedicated Linear issue that **blocks** [CES-39](https://linear.app/personal-interests-llc/issue/CES-39).


| #   | Topic                                                                                                                                                                                         | Linear                                                                                                                              | Status |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1   | Maintenance UX contract vs `data-model.md` / Drift — **resolved in schema v2**: `category` + `shop` added, `odometer_m` nullable, `cost_cents` / `currency_code` stay `NOT NULL` with form-side defaults; reminders remain on `maintenance_rules`. See [DATA_CONTRACTS.md §Maintenance entry contract](DATA_CONTRACTS.md#maintenance-entry-contract) and migration `0002_add_maintenance_events_category_shop` | [CES-53](https://linear.app/personal-interests-llc/issue/CES-53/align-maintenance-ux-contract-with-data-model-blocks-ces-39)        | Done   |
| 2   | Date-only maintenance vs `TIMESTAMPTZ` — **resolved:** single `performed_at` instant; see [DATA_CONTRACTS.md § Performed time (maintenance)](DATA_CONTRACTS.md#performed-time-maintenance) + [data-model.md](../../specs/data-model.md) § `maintenance_events` | [CES-54](https://linear.app/personal-interests-llc/issue/CES-54/define-date-only-maintenance-vs-timestamptz-blocks-ces-39)          | Done   |
| 3   | Visual system bootstrap — semantic tokens, fonts (`pubspec`), `ThemeData` / dark default, `LedgerCard` / `LedgerTile` / hairline primitives per `cestovni-styling.md`                         | [CES-55](https://linear.app/personal-interests-llc/issue/CES-55/flutter-visual-system-bootstrap-per-cestovni-styling-blocks-ces-39) | Open   |
| 4   | Shell navigation + **active vehicle** + default vehicle — target tabs (Log / History / Metrics / Maint), persistence, interaction with settings                                               | [CES-56](https://linear.app/personal-interests-llc/issue/CES-56/shell-tabs-active-vehicle-default-vehicle-model-blocks-ces-39)      | Open   |


**CES-39** is **blocked in Linear** by each **open** critical-gap issue below (and any upstream dependency such as **CES-37** / **CES-38** on the card), until the corresponding row is **Done** and relations are updated. There is no separate “Blocked” workflow state on the Cestovni team — use the blocking relations as the source of truth.

**Closure criteria (per row):** Spec or UX doc updated to match the chosen implementation; any schema migration documented; linked PR merged; this table’s **Status** set to **Done**.

---

## Sharp edges — track here or spin child issues

Not automatic blockers for CES-39 unless product promotes them.


| Area                    | Gap                                                                                                                     | Suggested owner |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------- |
| Draft lifecycle         | Single vs multiple drafts per vehicle, discard/dirty navigation, “resume draft” entry points                            | Product + UX    |
| Metrics                 | “Cost over time” bucketing (day/week/month by range), empty buckets; multi-currency until **CES-51**                    | Product + eng   |
| Soft delete             | Undo window vs confirm-only; whether deleted rows reappear anywhere                                                     | Product         |
| Light theme             | Wired in: `light-parchment` set + `full-scroll/` subfolder referenced by `cestovni-full-views.md` and `cestovni-add-vehicle-cta.md`; `README` lists both variants. Dark remains first-load default per `cestovni-styling.md` §5. | Design          |
| Empty / loading / error | Copy and patterns (no skeleton shimmer per style spec) per screen                                                       | Product + UX    |
| Vehicle CRUD UX         | Field-level spec beyond “must ship” list in `DELIVERY_ACCEPTANCE.md`                                                    | Product         |
| Currency display        | ISO-4217 minor units (not always 2 decimals)                                                                            | Eng + product   |
| i18n / a11y             | Dynamic type, locale number/date formatting, semantics labels                                                           | Eng (Stage 5/6) |
| Test matrix             | §4 of `SENIOR_REVIEW_CHECKLIST.md` — map each bullet to a PR or issue                                                   | Eng             |


---

## References

- Delivery prerequisite: `[../delivery-plan-v1.md](../delivery-plan-v1.md)` (M1 — UX gap closure).
- Data model (normative): `[../../specs/data-model.md](../../specs/data-model.md)`.
- UX contracts under review: `[DATA_CONTRACTS.md](DATA_CONTRACTS.md)`, `[cestovni-views.md](cestovni-views.md)`, `[DELIVERY_ACCEPTANCE.md](DELIVERY_ACCEPTANCE.md)`, `[cestovni-styling.md](cestovni-styling.md)`.
- Drift mirrors today: `client/lib/db/tables/maintenance_events.dart`, `client/lib/db/tables/maintenance_rules.dart`, `client/lib/app/shell.dart`, `client/lib/app/app.dart`.

---

## Linear issue bodies (copy if API not used)

Use team **Cestovni**, project **Cestovni**, labels **type:improvement** (or **type:spike** where noted), **effort:medium** unless adjusted. Add relation: **This issue blocks CES-39**.

### Issue 1 — Maintenance contract alignment *(resolved 2026-04-22 — archive for imports / history)*

**Title:** Align maintenance UX contract with data model (blocks CES-39)

**TL;DR**

- **Shipped:** additive Drift schema v2 (`0002_add_maintenance_events_category_shop`), `DATA_CONTRACTS.md` + `data-model.md` + `maintenance_events.dart` aligned; tracker row 1 = **Done**.
- **Linear hygiene:** set issue **Done**, remove **blocks** relation to CES-39 if still wired (see issue comments on CES-53 / CES-39).

**What changed (summary)**

- `category` + `shop` on `maintenance_events`; `odometer_m` nullable; `cost_cents` / `currency_code` stay `NOT NULL` with form defaults (`0`, `settings.currency_code`); reminders stay on `maintenance_rules` per contract.
- UX field names: `performedAt` in contracts (not `serviceAt`).

**Spec:** `docs/specs/data-model.md`  
**UX refs:** `docs/product/ux/DATA_CONTRACTS.md`, `docs/product/ux/cestovni-views.md`, `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`

---

### Issue 2 — Date-only maintenance *(resolved 2026-04-24 — archive for imports / history)*

**Title:** Define date-only maintenance storage vs TIMESTAMPTZ (blocks CES-39)

**TL;DR**

- **Shipped:** one column `performed_at` (UTC instant); no `DATE` / parallel text column. Normative **date-only** and **date+time** write paths in `docs/product/ux/DATA_CONTRACTS.md` § *Performed time (maintenance)*; `docs/specs/data-model.md` § `maintenance_events` notes; tracker row 2 = **Done**.
- **Linear hygiene:** set issue **Done**, remove **blocks** relation to **CES-39** if still wired.

**Spec:** `docs/specs/data-model.md`  
**UX refs:** `docs/product/ux/DATA_CONTRACTS.md` § *Performed time (maintenance)*, `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`

---

### Issue 3 — Visual system bootstrap

**Title:** Flutter visual system bootstrap per cestovni-styling (blocks CES-39)

**TL;DR**

- App still uses generic `ThemeData(colorSchemeSeed: …)`; spec defines OKLCH tokens, fonts, ledger components, grain background.
- Land shared theme + primitives so feature work does not fork ad-hoc styles.

**Acceptance criteria**

- Semantic color/text style tokens (light + dark) consumed by shell or a pilot screen.
- Fonts declared in `pubspec.yaml` per spec (or documented deviation).
- Reusable primitives: ledger card/tile + hairline divider (names can match spec).
- No feature-level raw hex for semantic roles.

**Spec:** `docs/specs/adr/003-mobile-stack.md`  
**UX refs:** `docs/product/ux/cestovni-styling.md`, `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`

---

### Issue 4 — Shell + active vehicle

**Title:** Shell tabs + active vehicle + default vehicle model (blocks CES-39)

**TL;DR**

- Target: Log / History / Metrics / Maint; current shell: Home / Settings / Debug.
- Define where active vehicle is shown, how it persists, and how it interacts with default vehicle in settings.

**Spec:** `docs/specs/data-model.md` + `docs/product/PRODUCT_BRIEF.md`  
**UX refs:** `docs/product/ux/cestovni-views.md`, `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`