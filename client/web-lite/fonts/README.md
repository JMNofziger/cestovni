# Self-hosted fonts (deferred)

Phase 1 ships with the spec's CSS fallback stacks only (`styles.css`):

- Headlines — `Fraunces` → Playfair Display, Georgia, serif
- Body / labels — `Inter` → system-ui, sans-serif
- Mono / pills / numeric — `JetBrains Mono` → IBM Plex Mono, monospace

To complete the visual contract (`docs/specs/pwa-lite-v1.md` §1), drop subset
woff2 files here and add matching `@font-face` rules with `font-display: swap`:

- Fraunces 600
- Inter 400, 600
- JetBrains Mono 400, 500

Target ~120–150 KB total. Add the files to `sw.js` `SHELL` precache once present.
