import 'package:drift/drift.dart';

/// Per-table restore cursor. Client-only: never exported, never outboxed.
///
/// `last_row_version` is the last `next_since` committed with a page
/// of `GET /changes` rows (`sync-protocol.md` §Cursor safety).
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  TextColumn get cursorTable => text().named('table_name')();

  IntColumn get lastRowVersion => integer()
      .named('last_row_version')
      .withDefault(const Constant(0))();

  TextColumn get updatedAt => text().named('updated_at')();

  @override
  String get tableName => 'sync_cursors';

  @override
  Set<Column> get primaryKey => {cursorTable};
}
