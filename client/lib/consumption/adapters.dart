/// Drift ↔ consumption-module boundary.
///
/// This is the ONLY file in `client/lib/consumption/` that is allowed to
/// import `package:drift/*` or `package:cestovni/db/*`. The rest of the
/// module is pure Dart so it can be reused server-side (M3) and tested
/// without a Drift runtime. `module_purity_test.dart` (Phase 2) enforces
/// this via grep.
///
/// TODO(CES-52): re-examine whether this dep direction should be
/// upgraded to a compile-time boundary (separate Dart package under
/// `client/packages/consumption/`). Trigger: when M3 server work begins
/// OR a second module starts consuming the math. See Linear Issue A
/// (CES-52). Related: CES-38, CES-39.
library;

import 'package:cestovni/db/app_database.dart' show FillUpRow;

import 'models.dart';

/// Maps a Drift [FillUpRow] to a pure [FillUp] value object.
///
/// `filledAt` is parsed once here as UTC `DateTime`; downstream math
/// treats it as opaque ordering key + future-tolerance comparison. We
/// parse with [DateTime.parse] which returns UTC for any ISO-8601 input
/// carrying a `Z` or offset suffix; the data-model spec mandates UTC
/// ISO-8601 in this column.
FillUp fillUpFromRow(FillUpRow row) {
  return FillUp(
    id: row.id,
    vehicleId: row.vehicleId,
    filledAt: DateTime.parse(row.filledAt).toUtc(),
    odometerM: row.odometerM,
    volumeUL: row.volumeUL,
    totalPriceCents: row.totalPriceCents,
    currencyCode: row.currencyCode,
    isFull: row.isFull,
    missedBefore: row.missedBefore,
    odometerReset: row.odometerReset,
    notes: row.notes,
  );
}

/// Convenience for bulk conversion.
List<FillUp> fillUpsFromRows(Iterable<FillUpRow> rows) =>
    rows.map(fillUpFromRow).toList(growable: false);
