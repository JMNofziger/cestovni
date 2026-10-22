import 'package:drift/drift.dart';

/// Local-only mark for a row whose outbox `insert` was discarded.
///
/// The domain row stays on the device. The Backup screen lists these
/// so the user can see it was not backed up. Never sent to the server.
@DataClassName('BackupMark')
class BackupMarks extends Table {
  TextColumn get markedTable => text().named('table_name')();

  TextColumn get rowId => text().named('row_id').withLength(min: 36, max: 36)();

  TextColumn get createdAt => text().named('created_at')();

  @override
  String get tableName => 'backup_marks';

  @override
  Set<Column> get primaryKey => {markedTable, rowId};
}
