/// Unified History ledger: fill-ups + maintenance (CES-67).
///
/// Spec: `docs/product/ux/DATA_CONTRACTS.md` §"History feed contract".
/// Ordering: event datetime DESC, then `id` DESC (client has no
/// separate `created_at`). Soft-deleted rows must already be excluded
/// by the repositories. Pure Dart — no Flutter.
library;

/// Kind of a History row.
enum LedgerKind { fuel, maint }

/// One row in the unified History stream.
class LedgerEntry {
  const LedgerEntry({
    required this.kind,
    required this.id,
    required this.eventAt,
    required this.vehicleId,
    this.fillUp,
    this.maintenance,
  });

  final LedgerKind kind;
  final String id;
  final DateTime eventAt;
  final String vehicleId;

  /// Set when [kind] is [LedgerKind.fuel].
  final Object? fillUp;

  /// Set when [kind] is [LedgerKind.maint].
  final Object? maintenance;
}

/// Merge fill-up + maintenance rows into newest-first History order.
///
/// [fuel] items are `(id, vehicleId, filledAtIso, row)`.
/// [maint] items are `(id, vehicleId, performedAtIso, row)`.
List<LedgerEntry> mergeLedgerEntries({
  required List<LedgerEntry> fuel,
  required List<LedgerEntry> maint,
}) {
  final List<LedgerEntry> all = [...fuel, ...maint];
  all.sort((a, b) {
    final int byTime = b.eventAt.compareTo(a.eventAt);
    if (byTime != 0) return byTime;
    return b.id.compareTo(a.id);
  });
  return all;
}

DateTime parseEventAt(String iso) => DateTime.parse(iso).toUtc();
