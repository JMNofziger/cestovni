import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'restore_service.dart';
import 'sync_client.dart';
import 'sync_config.dart';

/// Long-lived restore run so the progress page and the shell banner
/// share one cursor walk. Lives above [MaterialApp].
class RestoreController extends ChangeNotifier {
  RestoreController({
    required this.db,
    SyncClient Function()? openClient,
  }) : _openClient = openClient;

  final AppDatabase db;
  final SyncClient Function()? _openClient;

  RestoreSnapshot snapshot = const RestoreSnapshot.idle();
  RestoreService? _service;
  SyncClient? _client;

  bool get isRunning => snapshot.phase == RestoreRunPhase.running;

  Future<void> start(RestoreReason reason) async {
    if (isRunning) return;
    final client = _open();
    if (client == null) {
      snapshot = const RestoreSnapshot(
        phase: RestoreRunPhase.failed,
        tables: [],
        rowsApplied: 0,
        message: 'Sync is not configured',
      );
      notifyListeners();
      return;
    }
    _client?.close();
    _client = client;
    final service = RestoreService(db: db, client: client);
    _service = service;
    try {
      await for (final next in service.run(reason: reason)) {
        snapshot = next;
        notifyListeners();
      }
    } finally {
      if (identical(_service, service)) _service = null;
    }
  }

  void cancel() => _service?.cancel();

  @override
  void dispose() {
    _service?.cancel();
    _client?.close();
    super.dispose();
  }

  SyncClient? _open() {
    final custom = _openClient;
    if (custom != null) return custom();
    const cfg = SyncConfig.fromEnvironment;
    if (!cfg.isConfigured) return null;
    return SyncClient(baseUrl: cfg.baseUrl, bearerToken: cfg.bearerToken);
  }
}
