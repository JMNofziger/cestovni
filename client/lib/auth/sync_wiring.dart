import 'package:http/http.dart' as http;

import '../sync/sync_client.dart';
import '../sync/sync_config.dart';
import 'auth_session.dart';

/// Sync client whose bearer is [AuthSession.bearer].
///
/// `bearerToken` (the `CESTOVNI_SYNC_TOKEN` define) is used only when
/// `bearer` returns null: the dev sync stub with no session. A network
/// failure while refreshing becomes a retriable [SyncHttpError] and
/// does not clear the session.
SyncClient syncClientFor(
  SyncConfig cfg, {
  AuthSession? session,
  http.Client? httpClient,
}) {
  return SyncClient(
    baseUrl: cfg.baseUrl,
    bearerToken: cfg.bearerToken,
    tokenProvider: session == null ? null : () => _bearer(session),
    refreshOnUnauthorized: session == null ? null : () => _refresh(session),
    httpClient: httpClient,
  );
}

/// URL plus either the dev token or a signed-in session.
bool syncTargetReady(SyncConfig cfg, AuthSession? session) {
  if (cfg.baseUrl.isEmpty) return false;
  if (cfg.bearerToken.isNotEmpty) return true;
  return session?.state is SignedIn;
}

Future<String?> _bearer(AuthSession session) async {
  try {
    return await session.bearer();
  } on AuthNetworkException catch (e) {
    throw SyncHttpError(statusCode: 0, message: e.message, retriable: true);
  }
}

Future<void> _refresh(AuthSession session) async {
  try {
    await session.refreshOnce();
  } on AuthNetworkException catch (e) {
    throw SyncHttpError(statusCode: 0, message: e.message, retriable: true);
  }
}
