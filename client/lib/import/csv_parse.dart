/// RFC 4180 CSV reader + strict scalar coercion for CES-70 import.
///
/// Spec: `docs/specs/export-import.md` § Input contract → CSV parsing
/// rules. Read-direction mirror of `client/lib/export/csv.dart`.
///
/// A ZIP is a user-editable file, so coercion is deliberately strict:
/// export writes bare digits with no grouping (`export/derived.dart`),
/// therefore anything else means the cell was edited and we would rather
/// fail loudly than guess. The one concession is boolean case, because
/// spreadsheets upper-case `true`/`false` on save.
///
/// Pure module: no Flutter, no Drift, no `dart:io`.
library;

import 'import_errors.dart';

/// One parsed CSV record. [line] is the 1-based physical line the record
/// started on, so an error can point at the offending row even when a
/// quoted `notes` field spans several lines.
class CsvRecord {
  const CsvRecord({required this.fields, required this.line});

  final List<String> fields;
  final int line;
}

/// Strip a leading UTF-8 BOM, if present.
String stripBom(String text) =>
    text.startsWith('\uFEFF') ? text.substring(1) : text;

/// Split [text] into records.
///
/// Accepts CRLF **and** LF terminators (a tool may normalize line
/// endings) and handles quoted fields containing either — export quotes
/// any field with a comma, quote, CR or LF, so a single record can span
/// multiple physical lines.
List<CsvRecord> parseCsv(String text, {required String file}) {
  final source = stripBom(text);
  final records = <CsvRecord>[];
  final length = source.length;
  var index = 0;
  var line = 1;

  while (index < length) {
    final startLine = line;
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var recordDone = false;

    while (index < length && !recordDone) {
      final char = source[index];

      if (inQuotes) {
        if (char == '"') {
          if (index + 1 < length && source[index + 1] == '"') {
            buffer.write('"');
            index += 2;
            continue;
          }
          inQuotes = false;
          index++;
          continue;
        }
        if (char == '\n') line++;
        buffer.write(char);
        index++;
        continue;
      }

      if (char == '"' && buffer.isEmpty) {
        inQuotes = true;
        index++;
        continue;
      }
      if (char == ',') {
        fields.add(buffer.toString());
        buffer.clear();
        index++;
        continue;
      }
      if (char == '\r') {
        index += (index + 1 < length && source[index + 1] == '\n') ? 2 : 1;
        line++;
        recordDone = true;
        continue;
      }
      if (char == '\n') {
        index++;
        line++;
        recordDone = true;
        continue;
      }
      buffer.write(char);
      index++;
    }

    if (inQuotes) {
      throw ImportException(
        ImportErrorCode.rowMalformed,
        'Unterminated quoted field.',
        file: file,
        line: startLine,
      );
    }

    fields.add(buffer.toString());

    // A lone empty field means a blank physical line. Export never emits
    // one, but a text tool may append it; skipping is tolerant without
    // accepting ambiguous data.
    final isBlankLine = fields.length == 1 && fields.single.isEmpty;
    if (!isBlankLine) {
      records.add(CsvRecord(fields: fields, line: startLine));
    }
  }

  return records;
}

// ───────────────────────────────────────────── scalar coercion

/// Bare optionally-negative integer. Rejects `1.0`, `1,234`, `1 234`,
/// `+5`, and padded forms like `007`.
final RegExp _integerPattern = RegExp(r'^-?(?:0|[1-9][0-9]*)$');

/// Requires an explicit UTC designator or numeric offset. Without this
/// an offset-less timestamp would be read as device-local and silently
/// shifted, which is a data-corruption bug rather than a parse error.
final RegExp _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$',
);

Never _invalid(
  String message, {
  required String file,
  required int line,
  required String column,
}) {
  throw ImportException(
    ImportErrorCode.valueInvalid,
    message,
    file: file,
    line: line,
    column: column,
  );
}

int? readNullableInt(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  if (raw.isEmpty) return null;
  if (!_integerPattern.hasMatch(raw)) {
    _invalid(
      'Expected a whole number with no separators, got "$raw".',
      file: file,
      line: line,
      column: column,
    );
  }
  return int.parse(raw);
}

int readRequiredInt(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  final value = readNullableInt(raw, file: file, line: line, column: column);
  if (value == null) {
    _invalid(
      'Required value is empty.',
      file: file,
      line: line,
      column: column,
    );
  }
  return value;
}

/// `true` / `false`, case-insensitive. `1`, `0`, `yes`, `no` are
/// rejected on purpose.
bool readRequiredBool(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  switch (raw.toLowerCase()) {
    case 'true':
      return true;
    case 'false':
      return false;
  }
  _invalid(
    'Expected true or false, got "$raw".',
    file: file,
    line: line,
    column: column,
  );
}

String? readNullableText(String raw) => raw.isEmpty ? null : raw;

String readRequiredText(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  if (raw.isEmpty) {
    _invalid(
      'Required value is empty.',
      file: file,
      line: line,
      column: column,
    );
  }
  return raw;
}

/// Parse an ISO-8601 instant and re-serialize it the way the
/// repositories do (`nowIsoUtc()` → `toUtc().toIso8601String()`).
///
/// Normalizing matters beyond tidiness: export writes second precision
/// (`...T00:00:00Z`) while local writes carry milliseconds
/// (`...T00:00:00.000Z`). Those two forms sort differently as strings,
/// and History orders by `filled_at` as text — so storing the export
/// form verbatim would interleave imported and locally-created rows
/// incorrectly when their instants tie.
String readTimestampUtc(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  if (raw.isEmpty) {
    _invalid(
      'Required timestamp is empty.',
      file: file,
      line: line,
      column: column,
    );
  }
  if (!_timestampPattern.hasMatch(raw)) {
    _invalid(
      'Expected an ISO-8601 timestamp in UTC (for example '
      '2026-01-31T08:15:00Z), got "$raw".',
      file: file,
      line: line,
      column: column,
    );
  }
  final DateTime parsed;
  try {
    parsed = DateTime.parse(raw);
  } on FormatException {
    _invalid(
      'Not a valid timestamp: "$raw".',
      file: file,
      line: line,
      column: column,
    );
  }
  return parsed.toUtc().toIso8601String();
}

String? readNullableTimestampUtc(
  String raw, {
  required String file,
  required int line,
  required String column,
}) {
  if (raw.isEmpty) return null;
  return readTimestampUtc(raw, file: file, line: line, column: column);
}
