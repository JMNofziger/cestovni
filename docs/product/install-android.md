# Installing Cestovni on Android (Stage 1)

**Status:** Draft — APK release pipeline lands in M-dist (after tagged CI artifact).

Stage 1 distribution is **direct APK** per [ADR 005](../specs/adr/005-distribution-channels.md). Google Play ($25 one-time) is optional later.

## Requirements

- Android device with **Install unknown apps** allowed for your browser or file manager.
- APK matching a published release tag (SHA-256 checksum published alongside the artifact).

## Steps (to be finalized when release job exists)

1. Download `cestovni-*.apk` from the GitHub Release for the chosen version.
2. Verify SHA-256 against the checksum in the release notes.
3. Open the APK and confirm install.
4. Launch **Cestovni** from the app drawer.

## Play Store

Not required for Stage 1. When listed, this doc will link to the Play listing.

## Related

- [ADR 005](../specs/adr/005-distribution-channels.md)
- [delivery-plan-v1.md](delivery-plan-v1.md) — M-dist track
