import 'package:cestovni/units/display_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundHalfEvenDouble', () {
    test('ties round to even', () {
      expect(roundHalfEvenDouble(0.5), 0);
      expect(roundHalfEvenDouble(1.5), 2);
      expect(roundHalfEvenDouble(2.5), 2);
      expect(roundHalfEvenDouble(3.5), 4);
    });

    test('non-ties round to nearest', () {
      expect(roundHalfEvenDouble(1.4), 1);
      expect(roundHalfEvenDouble(1.6), 2);
      expect(roundHalfEvenDouble(198689.195), 198689);
    });
  });

  group('entry → canonical (si-units.md examples)', () {
    test('km → m', () {
      expect(distanceToMeters(45.678, 'km'), 45678);
      expect(distanceToMeters(50000, 'km'), 50000000);
    });

    test('mi → m (123.456 × 1 609.344 = 198 683.173…)', () {
      expect(distanceToMeters(123.456, 'mi'), 198683);
    });

    test('L → µL', () {
      expect(volumeToMicroliters(42.183, 'L'), 42183000);
    });

    test('gal → µL (13.157 × 3 785 411 784 = 49 804 662 842.09)', () {
      expect(volumeToMicroliters(13.157, 'gal'), 49804662842);
    });

    test('major → cents', () {
      expect(majorToCents(67.89), 6789);
    });
  });

  group('canonical → display', () {
    test('meters → whole km / mi', () {
      expect(metersToDisplayWhole(45678, 'km'), 46);
      expect(metersToDisplayWhole(198683, 'mi'), 123);
      // 1500 mi exactly: 1500 × 1609.344 m.
      expect(metersToDisplayWhole(2414016, 'mi'), 1500);
    });

    test('formatDistance adds separators + unit', () {
      expect(formatDistance(51460000, 'km'), '51,460 km');
      expect(formatDistance(2414016, 'mi'), '1,500 mi');
    });

    test('volumeToDisplay formats L and gal', () {
      expect(volumeToDisplay(13100000, 'L'), '13.10');
      expect(volumeToDisplay(3785411784, 'gal'), '1.00');
      expect(volumeToDisplay(42183000, 'L', decimals: 3), '42.183');
    });

    test('formatMoney uses symbol or code prefix', () {
      expect(formatMoney(4520, 'EUR'), '€45.20');
      expect(formatMoney(4520, 'USD'), '\$45.20');
      expect(formatMoney(4520, 'CZK'), 'CZK 45.20');
      expect(formatMoney(123456, 'EUR'), '€1,234.56');
    });
  });

  group('economy', () {
    test('useMpg only for mi + gal', () {
      expect(useMpg('mi', 'gal'), isTrue);
      expect(useMpg('km', 'L'), isFalse);
      expect(useMpg('mi', 'L'), isFalse);
      expect(useMpg('km', 'gal'), isFalse);
    });

    test('L/100km tenths (µL/m ratio, banker tie)', () {
      // 87 L over 1 200 km = 7.25 L/100km → tie → 7.2 (72 is even).
      expect(
        economyTenths(distanceM: 1200000, volumeUL: 87000000, mpg: false),
        72,
      );
    });

    test('MPG tenths', () {
      // 100 mi (160 934 m rounded) on 4 gal → 25.0 MPG.
      expect(
        economyTenths(
            distanceM: 160934, volumeUL: 15141647136, mpg: true),
        250,
      );
    });

    test('null on zero distance or volume', () {
      expect(economyTenths(distanceM: 0, volumeUL: 1, mpg: false), isNull);
      expect(economyTenths(distanceM: 1, volumeUL: 0, mpg: true), isNull);
    });

    test('formatTenths renders one decimal', () {
      expect(formatTenths(72), '7.2');
      expect(formatTenths(250), '25.0');
    });
  });
}
