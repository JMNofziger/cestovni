/// Integer banker's-rounding helpers.
///
/// The consumption math spec (`docs/specs/consumption-math.md`) mandates
/// "round-half-to-even at the final division step". All display-tenths
/// values (L/100km, cents/km, cents/L, MPG) funnel through one of these
/// two helpers so rounding semantics are asserted in one place.
///
/// No floating point. No `dart:math` dependencies.
library;

/// Divides `numerator / denominator` and rounds the quotient using
/// round-half-to-even ("banker's rounding").
///
/// Throws [ArgumentError] on `denominator == 0`.
///
/// Semantics verified against the spec examples:
///   divideRoundHalfEven(7, 2)   ==  4   // 3.5 → nearest even is 4
///   divideRoundHalfEven(5, 2)   ==  2   // 2.5 → nearest even is 2
///   divideRoundHalfEven(-5, 2)  == -2   // -2.5 → nearest even is -2
///   divideRoundHalfEven(-7, 2)  == -4   // -3.5 → nearest even is -4
///
/// For absolute remainders strictly less than half, truncate toward the
/// quotient. For remainders strictly greater than half, round away from
/// zero. For exact halves, pick whichever of the two neighbours is even.
///
/// INT64 overflow: this routine performs no multiplication, so as long as
/// both operands fit in INT64 the result does too. Callers that need to
/// pre-multiply (e.g. MPG) must use [divideRoundHalfEvenBig].
int divideRoundHalfEven(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError.value(denominator, 'denominator', 'must be non-zero');
  }

  final int q = numerator ~/ denominator;
  final int r = numerator - q * denominator;

  if (r == 0) return q;

  final int absR2 = r.abs() * 2;
  final int absD = denominator.abs();

  if (absR2 < absD) return q;

  // Direction to the "away from truncated quotient" neighbour. Because
  // Dart's `~/` truncates toward zero, the neighbour is `q + stepSign`,
  // where stepSign has the sign of (numerator * denominator).
  final int stepSign =
      (numerator < 0) ^ (denominator < 0) ? -1 : 1;

  if (absR2 > absD) return q + stepSign;

  // Exact tie — pick the even neighbour.
  final bool qEven = q.isEven;
  return qEven ? q : q + stepSign;
}

/// BigInt variant of [divideRoundHalfEven].
///
/// Required for MPG math where the numerator
/// `D_m × 1000 × 3_785_411_784 × 10` overflows INT64 at realistic
/// lifetime inputs (D ≈ 10⁹ m → numerator ≈ 3.8 × 10²²).
BigInt divideRoundHalfEvenBig(BigInt numerator, BigInt denominator) {
  if (denominator == BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator', 'must be non-zero');
  }

  final BigInt q = numerator ~/ denominator;
  final BigInt r = numerator - q * denominator;

  if (r == BigInt.zero) return q;

  final BigInt absR2 = r.abs() * BigInt.two;
  final BigInt absD = denominator.abs();

  if (absR2 < absD) return q;

  final BigInt stepSign =
      (numerator.isNegative ^ denominator.isNegative)
          ? -BigInt.one
          : BigInt.one;

  if (absR2 > absD) return q + stepSign;

  final bool qEven = q.isEven;
  return qEven ? q : q + stepSign;
}
