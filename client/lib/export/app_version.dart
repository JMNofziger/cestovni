/// App version string written into `manifest.json`.
///
/// Locked decision 6: injected into the assembler so tests are
/// deterministic. Keep in lockstep with `client/pubspec.yaml` `version`
/// (the `+build` suffix is stripped — spec wants a semver string).
const String kAppVersion = '0.0.1';

/// Stage 1 export is Android-only (ADR 005 — PWA-lite has no export).
const String kExportAppPlatform = 'android';
