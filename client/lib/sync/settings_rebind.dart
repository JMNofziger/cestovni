import 'package:http/http.dart' as http;

import '../db/app_database.dart';
import '../db/repositories/settings_repository.dart';
import 'restore_apply.dart';
import 'sync_client.dart';

/// Runs [SettingsRepository.rebindToUser] with the access token from
/// the session that is about to be reported as signed in.
///
/// An empty [baseUrl] has no manifest to read, so the unsynced row is
/// rewritten locally. A configured origin loads
/// `GET /api/v1/restore/manifest` and, when the server already has the
/// one settings row, restores it.
Future<void> rebindSettingsOnSignIn({
  required AppDatabase db,
  required String baseUrl,
  required String accessToken,
  required String userId,
  http.Client? httpClient,
}) async {
  if (baseUrl.isEmpty) {
    await SettingsRepository(
      db,
      server: const _OfflineSettingsServer(),
    ).rebindToUser(userId);
    return;
  }
  final client = SyncClient(
    baseUrl: baseUrl,
    bearerToken: accessToken,
    httpClient: httpClient,
  );
  try {
    await SettingsRepository(
      db,
      server: SyncSettingsServer(db: db, client: client),
    ).rebindToUser(userId);
  } finally {
    client.close();
  }
}

/// Manifest plus the existing settings restore, authorized by the
/// access token already in hand. This client does not refresh.
class SyncSettingsServer implements SettingsServer {
  SyncSettingsServer({required this.db, required this.client});

  final AppDatabase db;
  final SyncClient client;

  @override
  Future<int> settingsRowCount() async {
    final manifest = await client.getRestoreManifest();
    for (final table in manifest.tables) {
      if (table.table == 'settings') return table.rowCount;
    }
    return 0;
  }

  @override
  Future<void> restoreSettings() async {
    final applier = RestoreApplier(db);
    var cursor = await applier.cursorFor('settings');
    while (true) {
      final page = await client.getChanges(table: 'settings', since: cursor);
      await applier.applyPage(
        table: 'settings',
        rows: page.rows,
        nextSince: page.nextSince,
      );
      if (!page.hasMore) return;
      if (page.nextSince <= cursor) {
        throw StateError('changes cursor did not advance for settings');
      }
      cursor = page.nextSince;
    }
  }
}

class _OfflineSettingsServer implements SettingsServer {
  const _OfflineSettingsServer();

  @override
  Future<int> settingsRowCount() async => 0;

  @override
  Future<void> restoreSettings() async {}
}
