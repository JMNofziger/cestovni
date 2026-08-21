/// Orchestrates pick → read → validate → confirm → apply (CES-70).
///
/// Spec: `docs/specs/export-import.md` § UX, § Replace semantics.
///
/// Foreground-only, matching export amendment A5: no background service,
/// no completion notification, no new runtime permission. This is the one
/// impure file in `client/lib/import/` — it owns `dart:io`, the platform
/// picker and the photo sandbox so the parser, validator and planner stay
/// testable without a device.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../db/app_database.dart';
import '../export/user_key_hash.dart';
import '../photos/photo_store.dart';
import 'apply.dart';
import 'import_errors.dart';
import 'plan.dart';
import 'validate.dart';
import 'zip_read.dart';

/// Word the user types to confirm a destructive import.
///
/// English and un-localized because the client has no i18n in v1. If
/// localization lands this must be localized or replaced with a non-text
/// affordance — an English-only destructive gate in a translated UI is a
/// trap (spec § Replace semantics → Confirmation).
const String importConfirmationKeyword = 'REPLACE';

/// Picks an archive and returns its bytes, or null when the user
/// cancels. Injectable so widget tests never reach the plugin.
typedef ArchivePicker = Future<Uint8List?> Function();

/// A validated archive plus what applying it would destroy. Produced
/// without writing anything.
class ImportPreview {
  const ImportPreview({required this.plan, required this.footprint});

  final ImportPlan plan;
  final LocalFootprint footprint;

  /// Whether the user must type [importConfirmationKeyword].
  ///
  /// False on a device with no history — the new-phone path, where there
  /// is nothing to lose and friction buys no safety.
  bool get requiresTypedConfirmation => !footprint.isEmpty;

  List<ImportWarning> get warnings => plan.warnings;
}

class ImportService {
  ImportService({
    required this.db,
    ArchivePicker? picker,
    PhotoStore? photoStore,
    ImportApplier? applier,
  })  : _picker = picker,
        _photoStore = photoStore,
        _applier = applier;

  final AppDatabase db;
  final ArchivePicker? _picker;
  final PhotoStore? _photoStore;
  final ImportApplier? _applier;

  ImportApplier get _apply => _applier ?? ImportApplier(db);

  /// Prompt for a `.zip`. Returns null when the user cancels.
  Future<Uint8List?> pickArchive() async {
    final injected = _picker;
    if (injected != null) return injected();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes != null) return bytes;

    final path = picked.path;
    if (path == null) {
      throw const ImportException(
        ImportErrorCode.notAZip,
        'That file could not be read.',
      );
    }
    return File(path).readAsBytes();
  }

  /// Validate [bytes] and measure the local data a replace would
  /// destroy. Performs **no** writes.
  Future<ImportPreview> preview(Uint8List bytes) async {
    final entries = readZipEntries(bytes, inflate: _inflateRaw);
    final plan = buildImportPlan(
      entries,
      localUserKeyHash: await _localUserKeyHash(),
    );
    final footprint = await _apply.measure(plan);
    return ImportPreview(plan: plan, footprint: footprint);
  }

  /// Apply [preview] with replace semantics.
  ///
  /// Throws [ImportErrorCode.notConfirmed] when the archive would
  /// destroy local history and [typedConfirmation] is not exactly
  /// [importConfirmationKeyword].
  ///
  /// Photo files for discarded drafts are deleted **after** the
  /// transaction commits. That ordering is deliberate: an interruption
  /// leaves files with no row, which `PhotoService.sweep` already
  /// collects as orphan files. Deleting first would leave rows pointing
  /// at missing files if the transaction rolled back.
  Future<ImportOutcome> commit(
    ImportPreview preview, {
    String? typedConfirmation,
  }) async {
    if (preview.requiresTypedConfirmation &&
        typedConfirmation != importConfirmationKeyword) {
      throw const ImportException(
        ImportErrorCode.notConfirmed,
        'Type $importConfirmationKeyword to confirm replacing this '
        "device's history.",
      );
    }

    final outcome = await _apply.apply(preview.plan);
    await _deleteOrphanedPhotoFiles(outcome.photoIdsToDelete);
    return outcome;
  }

  Future<void> _deleteOrphanedPhotoFiles(List<String> photoIds) async {
    if (photoIds.isEmpty) return;
    final store = _photoStore ?? PhotoStore.appSandbox();
    for (final id in photoIds) {
      try {
        await store.delete(id);
      } catch (_) {
        // The rows are already gone, so a file left behind is a
        // harmless orphan the next photo sweep collects. Never fail a
        // committed import over cleanup.
      }
    }
  }

  /// Local `user_key_hash` for the archive-vs-device comparison.
  ///
  /// Read-only on purpose — `preview` must not write, so this does not
  /// bootstrap the settings row. An empty string means "no local
  /// identity yet", which suppresses the mismatch warning.
  Future<String> _localUserKeyHash() async {
    final settings = await db.select(db.appSettings).getSingleOrNull();
    if (settings == null) return '';
    return userKeyHashFromSettingsId(settings.id);
  }
}

/// Raw DEFLATE inflater backed by `dart:io`. Injected into
/// [readZipEntries] so the reader itself stays pure.
Uint8List _inflateRaw(Uint8List deflated, int expectedSize) {
  final decoded = ZLibDecoder(raw: true).convert(deflated);
  return decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
}
