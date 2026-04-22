# Cestovni — Visual System Spec

A handoff reference for the visual language: tokens, components, typography, and motion. The aesthetic is a **paper ledger / parchment** — warm cream surfaces, near-black "ink", hairline rules, hard offset shadows, mono labels.

This is a cross-platform spec. For app implementation, treat these as semantic design tokens that map into Flutter `ThemeData`, `ColorScheme`, and shared style constants.

---

## 1. Concept

- Ledger / parchment metaphor: cream paper, ink lines, mono labels evoke a maintained journal.
- **Hard ink borders** (1px, full-opacity ink) on cards, tiles, inputs, buttons — no soft shadows by default.
- **Hard offset shadow** `3px 3px 0 0 ink` on primary surfaces (`ledger-card`) — gives a stamped/printed feel; no blur.
- **Hairline rules** (1px ink) separate sections instead of background contrast.
- **Mono micro-labels** (`label-mono`) for every meta line: uppercase, tracked, muted.
- **Subtle radial paper grain** on the body in both themes for texture.

---

## 2. Typography

- **Serif — Fraunces** (`fontSerif`): page titles, card headlines, large numerals, lifetime totals. Weight 600, tracking `-0.01em`. Fallback: Playfair Display, Georgia, serif.
- **Sans — Inter** (`fontSans`): body copy, descriptions, form labels. System fallback.
- **Mono — JetBrains Mono** (`fontMono`): labels, pills, button text, numeric data, vehicle names in selector. Fallback: IBM Plex Mono, monospace.

`labelMono` style token — the workhorse meta label:

```
font-family: mono
text-transform: uppercase
letter-spacing: 0.12em
font-size: 0.7rem
color: mutedForeground
```

Primary headings should default to Fraunces 600.

---

## 3. Spacing & Radius

- **Radius**: `radiusBase = 6dp`. Variants: `2dp`, `4dp`, `6dp`, `10dp`.
- **Page width target**: content max-width `~672dp` on larger screens with centered column and `16dp` horizontal padding.
- **Section rhythm**: titles -> hairline -> content. Between major blocks: `16-24dp`.
- **Tile padding**: `12dp` inside tiles; `24dp` inside primary cards.
- **Bottom safe area**: always honor platform safe-area insets for bottom nav and fixed CTAs.
- **Hairline pattern**: label + 1px rule divider is used across sections.

---

## 4. Light Mode Palette

All values are OKLCH (authoritative) with sRGB hex approximations for reference.

### Surfaces


| Token          | OKLCH                  | ≈ Hex     | Use                                       |
| -------------- | ---------------------- | --------- | ----------------------------------------- |
| `paper`      | `oklch(0.96 0.018 85)` | `#F1EAD7` | App background, cards                     |
| `paperDeep` | `oklch(0.92 0.025 85)` | `#E5DCC4` | Tiles, inset blocks, secondary surface    |
| `card`       | `oklch(0.98 0.012 85)` | `#F7F2E3` | Primary card fill                         |
| `background` | = paper                | —         | Screen background                         |


### Ink & rules


| Token                | OKLCH                  | ≈ Hex     | Use                            |
| -------------------- | ---------------------- | --------- | ------------------------------ |
| `ink`              | `oklch(0.18 0.01 60)`  | `#2A2620` | Text, borders, primary fills   |
| `rule`             | `oklch(0.35 0.015 60)` | `#574F45` | Hairline rules, subtle borders |
| `mutedForeground` | `oklch(0.42 0.015 60)` | `#6B6157` | Subtitles, label-mono color    |


### Accent & semantics


| Token                     | OKLCH                  | ≈ Hex     | Use                                            |
| ------------------------- | ---------------------- | --------- | ---------------------------------------------- |
| `accent`                | `oklch(0.65 0.18 40)`  | `#D2733A` | Burnt orange — chart overlays, highlight pills |
| `good`                  | `oklch(0.55 0.13 145)` | `#4F8C5A` | Positive deltas                                |
| `warn`                  | `oklch(0.7 0.16 75)`   | `#D9A23A` | Reminders, partial-fill pill                   |
| `bad` / `destructive` | `oklch(0.5 0.21 27)`   | `#C5321F` | Delete actions                                 |


### Charts (light)


| Token       | OKLCH                  | ≈ Hex                |
| ----------- | ---------------------- | -------------------- |
| `chart1` | `oklch(0.18 0.01 60)`  | `#2A2620` ink        |
| `chart2` | `oklch(0.65 0.18 40)`  | `#D2733A` orange     |
| `chart3` | `oklch(0.55 0.13 145)` | `#4F8C5A` green      |
| `chart4` | `oklch(0.7 0.16 75)`   | `#D9A23A` amber      |
| `chart5` | `oklch(0.45 0.1 250)`  | `#4861A0` slate-blue |


### Tooltip (light)

- Background: `paper`, border: `1px ink`, radius `radiusBase`, no shadow. Mono labels, ink values.

---

## 5. Dark Mode Palette

Theme is controlled by app preference. Default theme on first load is **dark**.

### Surfaces


| Token          | OKLCH                  | ≈ Hex     | Use                      |
| -------------- | ---------------------- | --------- | ------------------------ |
| `paper`      | `oklch(0.16 0.01 60)`  | `#1F1B16` | Deep charcoal background |
| `paperDeep` | `oklch(0.22 0.012 60)` | `#2D2922` | Tile fill                |
| `card`       | `oklch(0.2 0.012 60)`  | `#28241E` | Card surface             |


### Ink & rules


| Token                | OKLCH                  | ≈ Hex     | Use                                                   |
| -------------------- | ---------------------- | --------- | ----------------------------------------------------- |
| `ink`              | `oklch(0.94 0.015 85)` | `#ECE3CD` | Cream "ink" — text, borders, primary fills (inverted) |
| `rule`             | `oklch(0.55 0.015 60)` | `#8B8278` | Hairline rules                                        |
| `mutedForeground` | `oklch(0.7 0.015 60)`  | `#B3AB9F` | Subtitles                                             |


### Accent & semantics


| Token           | OKLCH                  | ≈ Hex     | Use                                  |
| --------------- | ---------------------- | --------- | ------------------------------------ |
| `accent`      | `oklch(0.7 0.18 40)`   | `#E68A4F` | Brighter orange for contrast on dark |
| `good`        | `oklch(0.55 0.13 145)` | `#4F8C5A` | (unchanged)                          |
| `warn`        | `oklch(0.7 0.16 75)`   | `#D9A23A` | (unchanged)                          |
| `destructive` | `oklch(0.6 0.21 27)`   | `#DA4530` | Slightly brighter red                |


### Tooltip (dark)

- Background: dark `card`, border `1px ink` (cream), mono labels in muted, values in ink.

> **Important**: in dark mode `ink` is **cream**, not black. "Ink" is a semantic role (the high-contrast mark on paper), not a literal color. Never hardcode literal black/white for primary foreground and borders.

---

## 6. Component recipes (semantic)

### Ledger card

- Surface: `card`
- Border: `1px ink`
- Radius: `radiusBase`
- Shadow: hard offset `x=3, y=3, blur=0, color=ink`
- Use for hero cards, recap cards, and primary content blocks.

### Ledger tile

- Surface: `paperDeep`
- Border: `1px ink`
- Radius: `radiusBase`
- Padding: `12dp`
- Use for compact stat and metric tiles.

### Hairline divider

- `1px rule` separator used between grouped sections.

### Safe-area bottom treatment

- Add bottom inset padding using platform safe-area values for nav bars and anchored CTAs.

---

## 7. Buttons

All primary action labels use mono uppercase styling with `0.1em` tracking.

- **Primary**: ink fill with paper text. Main CTAs are full width and taller (`~48dp`).
- **Outline**: paper fill, ink border/text. Use for secondary actions and utility actions.
- **Ghost icon**: square icon button with no visible border by default; reserved for header/row actions.
- **Destructive**: destructive fill and high-contrast text; only for irreversible actions.
- **Toggle group**: bordered buttons where active state inverts to ink fill + paper text.

Press feedback should be subtle and immediate (small translate or opacity shift).

---

## 8. Form controls

- **Input / textarea**: ink border, paper surface, mono-aligned numeric fields where needed. Placeholder/assistive text at ~60% contrast.
- **Select / picker**: same border/radius language as input; menu items follow mono micro-label style.
- **Date & time picker**: native platform picker with consistent label and border shell.
- **Switch** (partial fill): paper-deep track + ink thumb; checked state inverts for clear active signal.
- **Color swatch picker**: circular swatches (`~28dp`) with explicit selection ring.
- **Validation**: inline destructive micro-copy under field; completion toasts/snackbars for save outcomes.

---

## 9. Iconography

- Use a single icon set consistently across the app (current implementation uses Material icons in Flutter).
- Keep visual weight consistent: lighter strokes for decorative/empty states, standard strokes for primary actions.
- Size targets:
  - Header actions: ~14dp icon in ~32dp button
  - Inline button icons: ~16dp
  - Bottom nav icons: ~20dp
  - Empty state hero icon: ~48dp with muted ink
- Core concepts to represent consistently: fuel, history, metrics, maintenance, settings, add, edit, delete, download, theme, previous/next, vehicle.

---

## 10. Pills (Micro-tags)

Bordered mono uppercase chips for type/status flags. Height `~18dp`, horizontal padding `~6dp`, font-size `~10-11sp`, tracking `0.12em`, radius `2dp`.


| Variant   | Border | Fill        | Text              | Use           |
| --------- | ------ | ----------- | ----------------- | ------------- |
| `default` | ink    | transparent | ink               | `FUEL`        |
| `accent`  | accent | accent      | accent-foreground | `MAINT`       |
| `warn`    | warn   | transparent | warn              | `PARTIAL`     |
| `muted`   | rule   | paper-deep  | muted-foreground  | category tags |


---

## 11. Charts (library-agnostic)

- **Lines**: `ink`, stroke width `~1.75`, points only on active/hovered values.
- **Trend overlay**: `accent`, dashed pattern.
- **Bars**: default `ink`; highlighted category may use `accent`.
- **Donut**: ink + accent + muted slices with paper separators.
- **Grid**: subtle dashed `rule` line with low opacity.
- **Axis ticks**: mono labels, small size (`~10sp`), muted foreground.
- **Tooltip**: paper/card background, `1px ink` border, no drop shadow, mono labels.
- **Legend**: compact mono labels with small swatches.

---

## 12. Page background

Both themes use a subtle two-layer radial dot grain behind primary surfaces:

```
background-image:
  radial-gradient(oklch(0.18 0.01 60 / 0.04) 1px, transparent 1px),
  radial-gradient(oklch(0.18 0.01 60 / 0.03) 1px, transparent 1px);
background-size: 28px 28px, 17px 17px;
background-position: 0 0, 9px 11px;
```

The dots use low-alpha ink so they read as paper grain in light mode and faint stippling in dark mode without needing separate patterns.

---

## 13. Motion

Deliberately minimal — the app should feel like printed paper, not a screen.

- **Tap feedback**: small tactile response on buttons and tabs.
- **Color transitions**: color-only transitions, ~150ms, on toggles and emphasis changes.
- **Sheet / dialog**: use framework defaults; avoid ornamental motion.
- **Charts**: short default mount animation (~400ms) is acceptable; avoid staggered or repeated re-entry effects.
- **No** decorative motion: no parallax, no auto-carousels, no scroll-triggered animation, no skeleton shimmer.

---

## 14. Implementation handoff checklist (Flutter)

- Define token constants once (light + dark) and expose through shared theme accessors.
- Centralize text styles (`serif`, `sans`, `mono`, `labelMono`) in app typography config.
- Build reusable primitives for `LedgerCard`, `LedgerTile`, and `HairlineDivider`.
- Enforce semantic colors (`ink`, `paper`, `rule`, etc.) in widgets; avoid literal hex usage in feature code.
- Validate dark/light parity against screenshots in `screenshots/dark-midnight/`.

