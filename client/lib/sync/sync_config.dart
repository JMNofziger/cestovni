/// Read-only sync configuration for the M3 outbox flush worker
/// (CES-44 gate slice).
///
/// Values are sourced from compile-time defines so Debug builds can
/// flip targets without code edits:
///
/// ```sh
/// flutter run \
///   --dart-define=CESTOVNI_SYNC_URL=http://10.0.2.2:8787 \
///   --dart-define=CESTOVNI_SYNC_TOKEN=dev-cestovni-token
/// ```
///
/// Android emulator note: `10.0.2.2` is the loopback alias for the
/// host machine, so the dev sync stub running on the laptop is
/// reachable from the emulator at `http://10.0.2.2:8787`.
library;

class SyncConfig {
  const SyncConfig({required this.baseUrl, required this.bearerToken});

  final String baseUrl;
  final String bearerToken;

  bool get isConfigured => baseUrl.isNotEmpty && bearerToken.isNotEmpty;

  static const SyncConfig fromEnvironment = SyncConfig(
    baseUrl: String.fromEnvironment(
      'CESTOVNI_SYNC_URL',
      defaultValue: '',
    ),
    bearerToken: String.fromEnvironment(
      'CESTOVNI_SYNC_TOKEN',
      defaultValue: '',
    ),
  );
}
