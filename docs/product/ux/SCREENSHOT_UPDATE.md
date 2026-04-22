# Screenshot update guide (lightweight)

Use this when design screenshots change and we need to keep UX references current.

## 1) Export and place files

- Export PNG screenshots at consistent mobile frame size.
- Put files in `docs/product/ux/screenshots/<theme-or-version>/` (e.g. `dark-midnight/`, `light-parchment/`).
- Use stable, screen-based names (no UUIDs):
  - `history.png`
  - `history-flip.png`
  - `history-fuel.png`
  - `log.png`
  - `metrics.png`
  - `maint.png`
  - `settings.png`

### Variants (single-viewport vs full-scroll)

Two capture variants coexist and serve different purposes — refresh them together when a design revision lands:

- **Single-viewport** — one mobile-frame capture per screen. Lives directly under the theme folder (e.g. `screenshots/light-parchment/log.png`). Used as the general style reference.
- **Full-scroll** — full content-height capture of each view (shows every section, card, and control without scrolling). Lives in a `full-scroll/` subfolder under the same theme (e.g. `screenshots/light-parchment/full-scroll/log.png`). Used by [`cestovni-full-views.md`](cestovni-full-views.md).

Naming convention: keep the same semantic filename in both variants (`log.png`, `history-top.png`, …). Do **not** add a `full-` prefix — the subfolder carries that semantic. The full-scroll set may include extra captures that don't exist in the single-viewport set (`history-top.png`, `history-bottom.png`, `metrics-top.png`, `metrics-bottom.png`, `history-detail.png`, `vehicle-dialog.png`, `confirm-dialog.png`, `empty.png`).

## 2) Update references

- Update `docs/product/ux/cestovni-views.md` screenshot paths if folder names changed.
- Update `docs/product/ux/cestovni-full-views.md` if full-scroll paths or filenames changed.
- Update `docs/product/ux/cestovni-add-vehicle-cta.md` if the CTA capture changed.
- If visual system changed, update `docs/product/ux/cestovni-styling.md`.
- Update `docs/product/ux/README.md`:
  - active screenshot set path (and full-scroll subfolder when applicable)
  - last refreshed date

## 3) Validate before merge

- Open each linked screenshot path from the docs and confirm it resolves.
- Confirm naming consistency across all screenshots (same screen names).
- Confirm no stale framework/file references in UX docs.

## 4) PR checklist (copy/paste)

- Screenshots copied to `docs/product/ux/screenshots/...` (single-viewport and/or `full-scroll/`)
- `cestovni-views.md` references updated
- `cestovni-full-views.md` references updated (if full-scroll set changed)
- `cestovni-add-vehicle-cta.md` references updated (if CTA capture changed)
- `cestovni-styling.md` updated if needed
- `ux/README.md` last refreshed date updated