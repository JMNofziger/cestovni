# Screenshot update guide (lightweight)

Use this when design screenshots change and we need to keep UX references current.

## 1) Export and place files

- Export PNG screenshots at consistent mobile frame size.
- Put files in `docs/product/ux/screenshots/<theme-or-version>/`.
- Use stable, screen-based names (no UUIDs):
  - `history.png`
  - `history-flip.png`
  - `history-fuel.png`
  - `log.png`
  - `metrics.png`
  - `maint.png`
  - `settings.png`

## 2) Update references

- Update `docs/product/ux/cestovni-views.md` screenshot paths if folder names changed.
- If visual system changed, update `docs/product/ux/cestovni-styling.md`.
- Update `docs/product/ux/README.md`:
  - active screenshot set path
  - last refreshed date

## 3) Validate before merge

- Open each linked screenshot path from the docs and confirm it resolves.
- Confirm naming consistency across all screenshots (same screen names).
- Confirm no stale framework/file references in UX docs.

## 4) PR checklist (copy/paste)

- [ ] Screenshots copied to `docs/product/ux/screenshots/...`
- [ ] `cestovni-views.md` references updated
- [ ] `cestovni-styling.md` updated if needed
- [ ] `ux/README.md` last refreshed date updated
