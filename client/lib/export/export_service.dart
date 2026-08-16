/// Orchestrates flush → snapshot → atomic ZIP write → share (CES-41).
///
/// Foreground-only (locked decision 5). Flush is best-effort: a network
/// failure does not fail the export; it shows up as `outbox_pending_count`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';
import '../db/repositories/outbox_repository.dart';
import '../sync/outbox_flush_worker.dart';
import '../sync/sync_client.dart';
import '../sync/sync_config.dart';
import 'app_version.dart';
import 'snapshot.dart';
import 'store_zip_sink.dart';
import 'user_key_hash.dart';
import 'zip_sink.dart';

typedef ShareZip = Future<void> Function(String path);

typedef ZipSinkFactory = ZipSink Function(File file);

class ExportService {
  ExportService({
    required this.db,
    Directory Function()? sandboxDir,
    this.flusher,
    ShareZip? share,
    ZipSinkFactory? zipSink,
    this.appVersion = kAppVersion,
    DateTime Function()? clock,
  })  : _sandboxDir = sandboxDir,
        _share = share,
        _zipSink = zipSink,
        _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final Directory Function()? _sandboxDir;
  final OutboxFlushWorker? flusher;
  final ShareZip? _share;
  final ZipSinkFactory? _zipSink;
  final String appVersion;
  final DateTime Function() _clock;

  /// Default flusher against [SyncConfig.fromEnvironment], or null when
  /// the stub URL is not configured (export still works offline).
  static OutboxFlushWorker? defaultFlusher(AppDatabase db) {
    const cfg = SyncConfig.fromEnvironment;
    if (!cfg.isConfigured) return null;
    return OutboxFlushWorker(
      outbox: OutboxRepository(db),
      client: SyncClient(baseUrl: cfg.baseUrl, bearerToken: cfg.bearerToken),
    );
  }

  Future<Directory> _dir() async {
    final supplied = _sandboxDir;
    if (supplied != null) return supplied();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Write the ZIP and return the final file. Does not share.
  Future<File> exportToFile() async {
    final worker = flusher ?? defaultFlusher(db);
    if (worker != null) {
      try {
        await worker.flushOnce();
      } catch (_) {
        // Best-effort. Pending count is recorded in the manifest.
      }
    }

    ExportSnapshot snapshot;
    try {
      snapshot = await takeExportSnapshot(db);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      snapshot = await takeExportSnapshot(db);
    }

    final exportedAt = _clock().toUtc();
    final hash = userKeyHashFromSettingsId(snapshot.settings.id);
    final name = exportFilename(userKeyHash: hash, exportedAt: exportedAt);
    final dir = await _dir();
    final tmp = File(p.join(dir.path, '$name.tmp'));
    if (tmp.existsSync()) tmp.deleteSync();
    final dest = File(p.join(dir.path, name));
    if (dest.existsSync()) dest.deleteSync();

    ZipSink? sink;
    try {
      sink = (_zipSink ?? FileZipSink.new)(tmp);
      if (sink is FileZipSink) sink.stamp = exportedAt;
      writeSnapshotToSink(
        sink: sink,
        snapshot: snapshot,
        appVersion: appVersion,
        exportedAt: exportedAt,
      );
      tmp.renameSync(dest.path);
      return dest;
    } catch (e) {
      sink?.abandon();
      if (tmp.existsSync()) tmp.deleteSync();
      if (dest.existsSync()) dest.deleteSync();
      rethrow;
    }
  }

  Future<File> exportAndShare() async {
    final file = await exportToFile();
    final share = _share;
    if (share != null) {
      await share(file.path);
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
    return file;
  }
}
