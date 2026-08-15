/// Sandboxed file storage for receipt photos.
///
/// Spec: `docs/specs/photo-pipeline.md` §"Local storage layout" —
/// `<app-sandbox>/photos/<uuid>.jpg`, alongside `cestovni.sqlite`.
///
/// This is one of two impure files in `client/lib/photos/` (see
/// `photo_service.dart`): it owns `dart:io` and `path_provider` so the rest
/// of the module stays testable without a device sandbox.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_export_guard.dart';

/// Reads and writes `photos/<id>.jpg` under a root resolved on first use.
///
/// The root is resolved lazily because `path_provider` is a plugin: a widget
/// test that never touches a photo must not pay a `MissingPluginException`
/// for the privilege of building the Log page.
class PhotoStore {
  PhotoStore({required Future<Directory> Function() resolveRoot})
      : _resolveRoot = resolveRoot;

  /// Production store — `<app-documents>/photos/`.
  factory PhotoStore.appSandbox() {
    return PhotoStore(resolveRoot: () async {
      final docs = await getApplicationDocumentsDirectory();
      return Directory(p.join(docs.path, photosDirectoryName));
    });
  }

  /// Test store — an injected temp directory.
  factory PhotoStore.inDirectory(Directory root) =>
      PhotoStore(resolveRoot: () async => root);

  final Future<Directory> Function() _resolveRoot;
  Directory? _root;

  Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;
    final resolved = await _resolveRoot();
    if (!await resolved.exists()) {
      await resolved.create(recursive: true);
    }
    return _root = resolved;
  }

  Future<File> fileFor(String id) async =>
      File(p.join((await root()).path, '$id.jpg'));

  Future<File> write(String id, Uint8List bytes) async {
    final file = await fileFor(id);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<bool> exists(String id) async => (await fileFor(id)).exists();

  /// Removes the JPEG for [id]. Returns false when it was already gone,
  /// which is not an error — the cleanup pass is expected to race with
  /// user deletes.
  Future<bool> delete(String id) async {
    final file = await fileFor(id);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  /// Ids of every JPEG currently on disk, used to spot files whose
  /// `photo_refs` row has gone (the reverse of an orphan row).
  Future<List<String>> storedIds() async {
    final dir = await root();
    if (!await dir.exists()) return const [];
    final ids = <String>[];
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (!name.endsWith('.jpg')) continue;
      ids.add(name.substring(0, name.length - '.jpg'.length));
    }
    ids.sort();
    return ids;
  }
}
