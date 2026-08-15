import 'package:cestovni/maintenance/history_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry _fuel(String id, DateTime at) => LedgerEntry(
      kind: LedgerKind.fuel,
      id: id,
      eventAt: at,
      vehicleId: 'v',
    );

LedgerEntry _maint(String id, DateTime at) => LedgerEntry(
      kind: LedgerKind.maint,
      id: id,
      eventAt: at,
      vehicleId: 'v',
    );

void main() {
  test('mergeLedgerEntries newest-first by eventAt then id DESC', () {
    final older = DateTime.utc(2026, 1, 1, 12);
    final newer = DateTime.utc(2026, 2, 1, 12);
    final same = DateTime.utc(2026, 3, 1, 12);

    final merged = mergeLedgerEntries(
      fuel: [
        _fuel('aaa-fuel', older),
        _fuel('zzz-fuel', same),
      ],
      maint: [
        _maint('mmm-maint', newer),
        _maint('yyy-maint', same),
      ],
    );

    expect(merged.map((e) => e.id).toList(), [
      'zzz-fuel', // same instant, id DESC vs yyy
      'yyy-maint',
      'mmm-maint',
      'aaa-fuel',
    ]);
    expect(merged.first.kind, LedgerKind.fuel);
    expect(merged[1].kind, LedgerKind.maint);
  });
}
