import 'package:cestovni/consumption/rounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('divideRoundHalfEven — spec examples', () {
    test('7 / 2 → 4 (tie, round to even up)', () {
      expect(divideRoundHalfEven(7, 2), 4);
    });
    test('5 / 2 → 2 (tie, round to even down)', () {
      expect(divideRoundHalfEven(5, 2), 2);
    });
    test('-5 / 2 → -2 (negative tie, round to even toward zero)', () {
      expect(divideRoundHalfEven(-5, 2), -2);
    });
    test('-7 / 2 → -4 (negative tie, round to even away from zero)', () {
      expect(divideRoundHalfEven(-7, 2), -4);
    });
  });

  group('divideRoundHalfEven — non-tie halves', () {
    test('3 / 2 → 2 (exact half, 1.5 → 2)', () {
      expect(divideRoundHalfEven(3, 2), 2);
    });
    test('1 / 2 → 0 (exact half, 0.5 → 0)', () {
      expect(divideRoundHalfEven(1, 2), 0);
    });
    test('-1 / 2 → 0 (exact half, -0.5 → 0)', () {
      expect(divideRoundHalfEven(-1, 2), 0);
    });
    test('-3 / 2 → -2 (exact half, -1.5 → -2)', () {
      expect(divideRoundHalfEven(-3, 2), -2);
    });
  });

  group('divideRoundHalfEven — off-half rounding', () {
    test('6 / 4 → 2 (1.5 → 2 even)', () {
      expect(divideRoundHalfEven(6, 4), 2);
    });
    test('10 / 4 → 2 (2.5 → 2 even)', () {
      expect(divideRoundHalfEven(10, 4), 2);
    });
    test('11 / 4 → 3 (2.75 → 3)', () {
      expect(divideRoundHalfEven(11, 4), 3);
    });
    test('9 / 4 → 2 (2.25 → 2)', () {
      expect(divideRoundHalfEven(9, 4), 2);
    });
    test('-11 / 4 → -3 (-2.75 → -3)', () {
      expect(divideRoundHalfEven(-11, 4), -3);
    });
  });

  group('divideRoundHalfEven — exact divisions', () {
    test('0 / 7 → 0', () {
      expect(divideRoundHalfEven(0, 7), 0);
    });
    test('42 / 7 → 6', () {
      expect(divideRoundHalfEven(42, 7), 6);
    });
    test('-42 / 7 → -6', () {
      expect(divideRoundHalfEven(-42, 7), -6);
    });
    test('42 / -7 → -6', () {
      expect(divideRoundHalfEven(42, -7), -6);
    });
  });

  group('divideRoundHalfEven — L/100km fixture derivations', () {
    test('50 000 000 µL / 1 000 000 m → 50 tenths (fixture #1)', () {
      expect(divideRoundHalfEven(50000000, 1000000), 50);
    });
    test('30 000 000 µL / 1 000 000 m → 30 tenths', () {
      expect(divideRoundHalfEven(30000000, 1000000), 30);
    });
  });

  group('divideRoundHalfEven — zero denominator', () {
    test('throws on 0 denominator', () {
      expect(() => divideRoundHalfEven(1, 0), throwsArgumentError);
    });
  });

  group('divideRoundHalfEven — INT64 edge values', () {
    test('large numerator near 1 << 62 is safe (no internal multiply)', () {
      // 2^62 = 4611686018427387904; divide by 2 → 2^61.
      const big = 4611686018427387904;
      expect(divideRoundHalfEven(big, 2), big ~/ 2);
    });
    test('max INT64 numerator / 1 is identity', () {
      const maxInt64 = 9223372036854775807;
      expect(divideRoundHalfEven(maxInt64, 1), maxInt64);
    });
  });

  group('divideRoundHalfEvenBig — MPG overflow path', () {
    test('matches int variant on small inputs', () {
      expect(divideRoundHalfEvenBig(BigInt.from(7), BigInt.from(2)),
          BigInt.from(4));
      expect(divideRoundHalfEvenBig(BigInt.from(5), BigInt.from(2)),
          BigInt.from(2));
      expect(divideRoundHalfEvenBig(BigInt.from(-5), BigInt.from(2)),
          BigInt.from(-2));
    });
    test('handles realistic MPG numerator that overflows INT64', () {
      // Gallon-in-µL has a decimal (3_785_411.784 µL), so work in
      // nanolitres: 1 US gal = 3_785_411_784 nL, and V_nL = V_uL × 1000.
      //   MPG = D / 1609.344 miles / (V × 1000 / 3_785_411_784 gal)
      //       = D × 3_785_411_784 / (V × 1_609_344)
      //   mpg_tenths = D × 10 × 3_785_411_784 / (V × 1_609_344)
      //
      // At lifetime scale (D = 10⁹ m) the numerator D × 10 × 3.785e9
      // ≈ 3.78e19, which exceeds INT64 max (~9.22e18). BigInt required.
      final d = BigInt.from(1000000000); // 10⁶ km in m
      final v = BigInt.from(100000000000); // 10⁵ L in µL = 10 L/100km burn
      final numerator =
          d * BigInt.from(10) * BigInt.parse('3785411784');
      final denominator = v * BigInt.from(1609344);
      // Sanity: INT64 max is 9_223_372_036_854_775_807.
      expect(numerator > BigInt.parse('9223372036854775807'), isTrue,
          reason: 'numerator must exceed INT64 to justify BigInt variant');
      final mpgTenths = divideRoundHalfEvenBig(numerator, denominator);
      // 10 L/100km ≈ 23.52 MPG → tenths ≈ 235.
      expect(mpgTenths.toInt(), 235);
    });
    test('throws on 0 denominator', () {
      expect(
        () => divideRoundHalfEvenBig(BigInt.one, BigInt.zero),
        throwsArgumentError,
      );
    });
  });
}
