# Cestovni UX references

Canonical UX reference artifacts for product and engineering live in this folder.

## Contents

- Styling system: [`cestovni-styling.md`](cestovni-styling.md)
- View-by-view UX descriptions: [`cestovni-views.md`](cestovni-views.md)
- Full-scroll screen reference (every view at full content height): [`cestovni-full-views.md`](cestovni-full-views.md)
- Add Vehicle CTA pill spec: [`cestovni-add-vehicle-cta.md`](cestovni-add-vehicle-cta.md)
- Delivery scope gates: [`DELIVERY_ACCEPTANCE.md`](DELIVERY_ACCEPTANCE.md)
- UX data contracts: [`DATA_CONTRACTS.md`](DATA_CONTRACTS.md)
- Senior review checklist: [`SENIOR_REVIEW_CHECKLIST.md`](SENIOR_REVIEW_CHECKLIST.md)
- Senior review packet: [`SENIOR_REVIEW_PACKET.md`](SENIOR_REVIEW_PACKET.md)
- UX gap closure tracker (M1 / CES-39 gate): [`UX_IMPLEMENTATION_GAPS.md`](UX_IMPLEMENTATION_GAPS.md)
- Screenshot update process: [`SCREENSHOT_UPDATE.md`](SCREENSHOT_UPDATE.md)
- Screenshot sets: [`screenshots/`](screenshots/)

## Screenshot sets

Two variants coexist per theme folder — they serve different purposes and should both be refreshed together when a design revision lands:

- **Single-viewport (general style reference)** — one mobile-frame capture per screen showing the intended look-and-feel. Semantic filenames (`log.png`, `history.png`, etc.).
- **Full-scroll (functional reference)** — full content-height captures of each view, used by [`cestovni-full-views.md`](cestovni-full-views.md) to show every section, card, and control. Lives in a `full-scroll/` subfolder per theme.

Current sets:

- `screenshots/dark-midnight/` — Dark Midnight reference set (`history.png`, `history-flip.png`, `history-fuel.png`, `log.png`, `metrics.png`, `maint.png`, `settings.png`). First-load default theme per [`cestovni-styling.md`](cestovni-styling.md) §5.
- `screenshots/light-parchment/` — Light Parchment reference set (same semantic filenames where present; includes the `add-vehicle-cta.png` pill detail).
- `screenshots/light-parchment/full-scroll/` — Light Parchment **full-scroll** set referenced by [`cestovni-full-views.md`](cestovni-full-views.md).

## Conventions

- Keep stable, semantic filenames (screen-based), not export UUID names.
- Add a new subfolder per theme or major visual revision.
- Treat these files as implementation references; acceptance criteria still live in specs and Linear issues.

## Ownership and refresh

- Owner: Product + Design
- Last refreshed: 2026-04-22 (added light-parchment full-scroll set + `cestovni-full-views.md` + `cestovni-add-vehicle-cta.md`)

