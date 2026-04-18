import 'package:drift/drift.dart';

import 'drafts.dart';

/// Client-only `photo_refs` table from docs/specs/photo-pipeline.md.
/// Receipt photos never leave the device — this table is not outboxed
/// and not exported.
@DataClassName('PhotoRefRow')
class PhotoRefs extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();

  TextColumn get draftId =>
      text().named('draft_id').withLength(min: 36, max: 36).references(Drafts, #id)();

  TextColumn get capturedAt => text().named('captured_at')();

  /// After compression.
  IntColumn get byteSize => integer().named('byte_size').customConstraint(
        'NOT NULL CHECK (byte_size >= 0)',
      )();

  /// Hex SHA-256; integrity check on read.
  TextColumn get sha256 => text().withLength(min: 64, max: 64)();

  /// `captured_at + 30d`, shortened to `min(now+7d, ttl_expires_at)` when
  /// the linked fill-up completes (photo-pipeline.md).
  TextColumn get ttlExpiresAt => text().named('ttl_expires_at')();

  @override
  Set<Column> get primaryKey => {id};
}
