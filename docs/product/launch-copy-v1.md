# Launch copy v1 (store, policy outline, in-app)

**Status:** Draft skeleton for Phase 2c — aligns with `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` and `[../specs/platform-compliance-v1.md](../specs/platform-compliance-v1.md)`.

**Not** final legal text. Product + counsel edit before submission.

---

## 1. App Store / Play — short description (≤80 characters target)

**Cestovni** — Offline fuel & maintenance log with export. Receipt photos stay on your device.

*(Localize; keep “device-only photos” and “export” if character limits force trims.)*

---

## 2. App Store / Play — full description (draft)

Cestovni helps you track fuel fill-ups and maintenance across vehicles — **even when you are offline**.

**Your data**

- History syncs to your account as **structured backup** when you sign in.
- **Receipt photos** are optional aids on **this device only**. They are **not uploaded**, not included in backup, and **not in your ZIP export**.
- Generate a **portable ZIP** (CSVs + manifest) anytime for spreadsheets or your own tools.

**Privacy & telemetry**

- Minimal diagnostics for reliability — **no ads**, no data brokerage. Details: see our privacy policy.

**Pricing**

- **Free to use.** Optional tips / donations never unlock core features — see in-app Support.

*Technical sources:* `[platform-compliance-v1.md](../specs/platform-compliance-v1.md)` §3–4, `[export-v1.md](../specs/export-v1.md)`, `[photo-pipeline.md](../specs/photo-pipeline.md)`.

---

## 3. Subtitle / promo text (examples)

- “Fuel log, offline-first, your export.”
- “Maintenance + fill-ups. Photos stay on-device.”

---

## 4. Keywords placeholder (App Store)

fuel, gas, mileage, maintenance, logbook, export, offline, CSV, privacy

---

## 5. “What’s new” template (v1.0.0)

- Initial release: offline logging, backup when signed in, ZIP export, optional receipt photos (on-device only).

---

## 6. Privacy policy — outline (H2 → compliance spec)

Each section should link or mirror `[platform-compliance-v1.md](../specs/platform-compliance-v1.md)`.


| Policy H2                           | Compliance anchor                                                               |
| ----------------------------------- | ------------------------------------------------------------------------------- |
| Who we are                          | §1 System recap + operator identity (fill at launch)                            |
| What we collect                     | §2 Data inventory                                                               |
| What we do **not** collect          | §3 bullets 1–3 (photos, export scope)                                           |
| Why we process data                 | Brief principles + §1 table “User expectation”                                  |
| Storage & security                  | ADR 001 / RLS pointer; client sandbox for photos                                |
| Backup & sync                       | §1 + `[sync-protocol.md](../specs/sync-protocol.md)` (user-facing summary only) |
| Export                              | §4                                                                              |
| Deletion & retention                | §5                                                                              |
| Telemetry                           | `[telemetry-allowlist.md](../specs/telemetry-allowlist.md)` summary + §5.3      |
| Children                            | §9 minors                                                                       |
| International transfers / residency | §9 residency                                                                    |
| Third parties                       | §7                                                                              |
| Changes                             | Standard boilerplate — counsel                                                  |
| Contact                             | Support email / DSA agent — fill at launch                                      |


---

## 7. In-app — “Data & privacy” screen (bullets)

Reuse the same sentences as `[platform-compliance-v1.md](../specs/platform-compliance-v1.md)` §3:

1. Receipt photos are saved **only on this device**; they are **not uploaded** to our servers and **cannot be restored** from backup or another phone.
2. Cloud backup (when signed in) covers your **fuel and maintenance history**, not receipt photos.
3. Export is **structured data only** (ZIP of spreadsheets); receipt images are **never** included.
4. Telemetry is limited to crashes and core reliability signals; **no ads**, no sale of personal data.

**Plus one line on donations:** Tips are optional and do **not** unlock features — see `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` (monetization row in Locked decisions).

---

## 8. Donations / no paywall (store-safe phrasing)

- “Cestovni is **free**. If you want to support development, you can leave an optional tip — **never required** to log fuel or export data.”
- Do **not** imply tips pay for server capacity in a way that contradicts the brief’s sustainability story; keep copy aligned with `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` monetization and principles sections.

---

## 9. Apple / Google checklist (submission day)

- `PrivacyInfo.xcprivacy` matches `[telemetry-allowlist.md](../specs/telemetry-allowlist.md)` § Apple privacy manifest.
- Play Data safety form matches `[platform-compliance-v1.md](../specs/platform-compliance-v1.md)` §8.3 mapping (updated for current Play Console definitions).
- Store screenshots do not show fake “cloud photo backup.”
- Support URL and privacy policy URL live.

---

## 10. Counsel handoff (for external review)

This file is **not** a privacy policy. Before publishing anything user-facing, counsel turns this into legal text. The package they need:

1. **Data inventory** — `[../specs/platform-compliance-v1.md](../specs/platform-compliance-v1.md)` §2 (rows cover App Store privacy labels + Play Data Safety).
2. **User-visible honesty (copy constraints)** — same file §3 bullets; these must survive translation into the final policy.
3. **Deletion / retention** — same file §5 (structured rows on account deletion; telemetry pepper lifecycle; photo TTL).
4. **Third-party SDKs** — same file §7 (allow-listed crash/telemetry SDK to be named at implementation time; not invented here).
5. **Payments posture** — §6 (free core; donations optional; IAP routing decision is counsel + store policy).
6. **Residency / minors** — §9 (no user-selectable region in v1; not directed at minors; EU DPA stack is operator-legal work before EU marketing claims).
7. **Service cessation** — §10 (notice + export + self-host pointer).

**Out of scope for counsel at this stage (engineering owns):** telemetry allow-list contents, data model, backup protocol, CI gate implementation.

**Status (product ack):** Launch copy skeletons above match `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` monetization + principles and `[../specs/platform-compliance-v1.md](../specs/platform-compliance-v1.md)` §3 without contradiction — 2026-04-17.