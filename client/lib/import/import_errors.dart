/// Typed failures and warnings for CES-70 ZIP import.
///
/// Spec: `docs/specs/export-import.md` § Error handling. Every
/// [ImportErrorCode] aborts before or inside the transaction and leaves
/// the database unchanged; warnings are surfaced in the confirm dialog
/// or the post-import summary and never block.
///
/// Pure module: no Flutter, no Drift, no `dart:io`.
library;

enum ImportErrorCode {
  notAZip('E_NOT_A_ZIP'),
  missingManifest('E_MISSING_MANIFEST'),
  manifestInvalid('E_MANIFEST_INVALID'),
  schemaVersionUnsupported('E_SCHEMA_VERSION_UNSUPPORTED'),
  photosPresent('E_PHOTOS_PRESENT'),
  rowVersionPresent('E_ROW_VERSION_PRESENT'),
  missingCsv('E_MISSING_CSV'),
  headerMismatch('E_HEADER_MISMATCH'),
  rowMalformed('E_ROW_MALFORMED'),
  valueInvalid('E_VALUE_INVALID'),
  cadenceMissing('E_CADENCE_MISSING'),
  fkOrphan('E_FK_ORPHAN'),
  duplicateId('E_DUPLICATE_ID'),
  settingsRowCount('E_SETTINGS_ROW_COUNT'),
  countMismatch('E_COUNT_MISMATCH'),
  notConfirmed('E_NOT_CONFIRMED'),
  txnFailed('E_TXN_FAILED');

  const ImportErrorCode(this.wire);

  final String wire;
}

/// A rejected import. [file], [line], and [column] are populated where
/// the spec asks for them so a user can find the offending cell.
class ImportException implements Exception {
  const ImportException(
    this.code,
    this.message, {
    this.file,
    this.line,
    this.column,
  });

  final ImportErrorCode code;
  final String message;

  /// ZIP entry name, e.g. `fill_ups.csv`.
  final String? file;

  /// 1-based physical line of the record's first line.
  final int? line;

  final String? column;

  /// Short user-facing sentence. Deliberately not the raw code.
  String get display {
    final where = <String>[
      ?file,
      if (line != null) 'line $line',
      if (column != null) 'column $column',
    ].join(', ');
    return where.isEmpty ? message : '$message ($where)';
  }

  @override
  String toString() => 'ImportException(${code.wire}): $display';
}

enum ImportWarningCode {
  unknownEntry('W_UNKNOWN_ENTRY'),
  differentSourceKey('W_DIFFERENT_SOURCE_KEY'),
  sourceHadPendingOutbox('W_SOURCE_HAD_PENDING_OUTBOX'),
  localDataReplaced('W_LOCAL_DATA_REPLACED'),
  queueDiscarded('W_QUEUE_DISCARDED'),
  draftsDiscarded('W_DRAFTS_DISCARDED');

  const ImportWarningCode(this.wire);

  final String wire;
}

class ImportWarning {
  const ImportWarning(this.code, this.message);

  final ImportWarningCode code;
  final String message;

  @override
  String toString() => '${code.wire}: $message';
}
