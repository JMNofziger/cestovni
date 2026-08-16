import 'package:cestovni/maintenance/performed_at.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dateOnlyToPerformedAtUtc', () {
    test('UTC timezone stores noon Z on the civil date', () {
      final utc = dateOnlyToPerformedAtUtc(
        DateTime.utc(2026, 4, 18),
        tzOffset: Duration.zero,
      );
      expect(utc, DateTime.utc(2026, 4, 18, 12));
      expect(utc.isUtc, isTrue);
    });

    test('positive offset subtracts so local noon is preserved', () {
      // Europe/Prague summer ≈ UTC+2: local 12:00 → 10:00Z.
      final utc = dateOnlyToPerformedAtUtc(
        DateTime.utc(2026, 7, 1),
        tzOffset: const Duration(hours: 2),
      );
      expect(utc, DateTime.utc(2026, 7, 1, 10));
    });
  });

  group('performedAtUtcToCivilDate', () {
    test('round-trips UTC noon to the same civil date', () {
      final stored = DateTime.utc(2026, 4, 18, 12);
      final civil = performedAtUtcToCivilDate(stored, tzOffset: Duration.zero);
      expect(civil, DateTime.utc(2026, 4, 18));
    });

    test('round-trips offset noon without calendar shift', () {
      const offset = Duration(hours: 2);
      final stored = dateOnlyToPerformedAtUtc(
        DateTime.utc(2026, 7, 1),
        tzOffset: offset,
      );
      final civil = performedAtUtcToCivilDate(stored, tzOffset: offset);
      expect(civil.year, 2026);
      expect(civil.month, 7);
      expect(civil.day, 1);
    });
  });

  test('tzOffsetForSettings UTC is zero', () {
    expect(tzOffsetForSettings('UTC'), Duration.zero);
  });
}
