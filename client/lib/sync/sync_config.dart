/// Sync configuration for the outbox flush worker.
///
/// The compile-time defines stay the dev path. A real sign-in flow
/// (later than CES-44) injects a JWT with [copyWithToken] or
/// [SyncClient.tokenProvider]. Both values are sent as
/// `Authorization: Bearer`. This client does not decode the token.
///
/// ```sh
/// flutter run \
///   --dart-define=CESTOVNI_SYNC_URL=http://10.0.2.2:8080 \
///   --dart-define=CESTOVNI_SYNC_TOKEN=dev-cestovni-token
/// ```
///
/// Android emulator note: `10.0.2.2` is the loopback alias for the
/// host machine. The dev sync stub listens on `:8787`; the CES-43 API
/// defaults to `:8080`.
library;

class SyncConfig {
  const SyncConfig({required this.baseUrl, required this.bearerToken});

  /// API origin, no trailing slash. Empty means sync is off.
  final String baseUrl;

  /// Static bearer. For dev this is the stub token. For the CES-43 API
  /// it is an HS256 JWT whose `sub` is the user UUID.
  final String bearerToken;

  bool get isConfigured => baseUrl.isNotEmpty && bearerToken.isNotEmpty;

  /// Same origin, different credential. Use this when auth mints a JWT
  /// at runtime instead of a compile-time define.
  SyncConfig copyWithToken(String token) {
    return SyncConfig(baseUrl: baseUrl, bearerToken: token);
  }

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
