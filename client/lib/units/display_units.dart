/// Entry/display unit conversion + formatting helpers (CES-65 / CES-66).
///
/// Spec: `docs/specs/si-units.md`. Canonical storage is SI-INT64
/// (meters / microliters / cents); every conversion here happens at
/// the display or entry boundary only. All rounding is banker's
/// (round-half-to-even) per spec §"Entry rounding rule" and
/// §"Display conversion rules".
///
/// Pure Dart — no Flutter or Drift imports so both UI and tests can
/// use it directly.
library;

import '../consumption/rounding.dart';

/// `1 L = 1 000 000 µL` (exact).
const int microlitersPerLiter = 1000000;

/// `1 US gal = 3 785 411 784 µL` (exact — 3.785411784 L × 10⁶).
const int microlitersPerUsGallon = 3785411784;

/// `1 mi = 1 609.344 m` (exact). Kept as scaled integer
/// (`1000 mi = 1 609 344 m`) so integer banker's rounding applies.
const int metersPerThousandMiles = 1609344;

/// `1 km = 1 000 m`.
const int metersPerKilometer = 1000;

/// Round a double to the nearest integer with banker's rounding
/// (ties go to the even neighbour). Dart's `round()` is
/// half-away-from-zero, which si-units.md forbids for conversions.
int roundHalfEvenDouble(double value) {
  final double floor = value.floorToDouble();
  final double diff = value - floor;
  if (diff > 0.5) return floor.toInt() + 1;
  if (diff < 0.5) return floor.toInt();
  final int f = floor.toInt();
  return f.isEven ? f : f + 1;
}

// ────────────────────────────── Entry → canonical

/// User-entered distance in `unit` (`km` | `mi`) → canonical meters.
int distanceToMeters(double value, String unit) {
  if (unit == 'mi') {
    return roundHalfEvenDouble(value * metersPerThousandMiles / 1000);
  }
  return roundHalfEvenDouble(value * metersPerKilometer);
}

/// User-entered volume in `unit` (`L` | `gal`) → canonical µL.
int volumeToMicroliters(double value, String unit) {
  final int perUnit =
      unit == 'gal' ? microlitersPerUsGallon : microlitersPerLiter;
  return roundHalfEvenDouble(value * perUnit);
}

/// User-entered major-currency amount → canonical cents.
int majorToCents(double value) => roundHalfEvenDouble(value * 100);

// ────────────────────────────── Canonical → display

/// Canonical meters → whole display units (`km` | `mi`), banker's
/// rounded (0 decimals per si-units.md list rule).
int metersToDisplayWhole(int meters, String unit) {
  if (unit == 'mi') {
    return divideRoundHalfEven(meters * 1000, metersPerThousandMiles);
  }
  return divideRoundHalfEven(meters, metersPerKilometer);
}

/// Canonical µL → display volume string with [decimals] places
/// (`L` | `gal`), banker's rounded at the last digit.
String volumeToDisplay(int microliters, String unit, {int decimals = 2}) {
  final int perUnit =
      unit == 'gal' ? microlitersPerUsGallon : microlitersPerLiter;
  int scale = 1;
  for (var i = 0; i < decimals; i++) {
    scale *= 10;
  }
  final int scaled = divideRoundHalfEven(microliters * scale, perUnit);
  if (decimals == 0) return formatThousands(scaled);
  final String sign = scaled < 0 ? '-' : '';
  final int abs = scaled.abs();
  final int whole = abs ~/ scale;
  final String frac = (abs % scale).toString().padLeft(decimals, '0');
  return '$sign${formatThousands(whole)}.$frac';
}

/// Canonical µL → display volume as a raw double (`L` | `gal`), for
/// pre-filling entry fields where a formatted string would not parse
/// back. Display strings should use [volumeToDisplay] instead.
double microlitersToDouble(int microliters, String unit) =>
    microliters /
    (unit == 'gal' ? microlitersPerUsGallon : microlitersPerLiter);

/// `12345` → `12,345`.
String formatThousands(int v) {
  final String sign = v < 0 ? '-' : '';
  final String s = v.abs().toString();
  final buf = StringBuffer(sign);
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Canonical meters → `12,345 km` / `7,668 mi`.
String formatDistance(int meters, String unit) =>
    '${formatThousands(metersToDisplayWhole(meters, unit))} $unit';

/// Currency symbol for the small set of expected v1 codes; falls back
/// to `CODE ` prefix for anything else (one currency per user in v1
/// per si-units.md, so this stays a display nicety, not an FX table).
String currencySymbol(String code) {
  switch (code) {
    case 'EUR':
      return '€';
    case 'USD':
      return '\$';
    case 'GBP':
      return '£';
    default:
      return '$code ';
  }
}

/// Canonical cents → `€45.20` / `$45.20` / `CZK 45.20`.
String formatMoney(int cents, String currencyCode) {
  final String sign = cents < 0 ? '-' : '';
  final int abs = cents.abs();
  final String major = formatThousands(abs ~/ 100);
  final String minor = (abs % 100).toString().padLeft(2, '0');
  return '${currencySymbol(currencyCode)}$sign$major.$minor';
}

// ────────────────────────────── Economy

/// MPG display applies only when both prefs are US units; every other
/// combination renders L/100km (per `DATA_CONTRACTS.md` the two
/// supported economy figures are MPG and L/100km).
bool useMpg(String distanceUnit, String volumeUnit) =>
    distanceUnit == 'mi' && volumeUnit == 'gal';

/// Economy in display tenths from canonical totals; `null` when
/// distance or volume is zero (callers render "—").
///
/// - L/100km tenths: `volume_uL / distance_m` (µL/m ≡ 0.1 L/100km).
/// - MPG tenths: `distance_m × 3 785 411 784 × 10 000 /
///   (1 609 344 × volume_uL)` via BigInt (overflows INT64 at
///   realistic lifetime inputs).
int? economyTenths({
  required int distanceM,
  required int volumeUL,
  required bool mpg,
}) {
  if (distanceM <= 0 || volumeUL <= 0) return null;
  if (!mpg) return divideRoundHalfEven(volumeUL, distanceM);
  final BigInt numerator = BigInt.from(distanceM) *
      BigInt.from(microlitersPerUsGallon) *
      BigInt.from(10000);
  final BigInt denominator =
      BigInt.from(metersPerThousandMiles) * BigInt.from(volumeUL);
  return divideRoundHalfEvenBig(numerator, denominator).toInt();
}

/// `72` → `7.2` (1-decimal economy display per si-units.md).
String formatTenths(int tenths) => '${tenths ~/ 10}.${tenths % 10}';

/// Uppercase field-label suffix for the distance unit (`KM` | `MI`).
String distanceUnitLabel(String unit) => unit.toUpperCase();

/// Uppercase field-label suffix for the volume unit (`L` | `GAL`).
String volumeUnitLabel(String unit) => unit.toUpperCase();

/// Economy unit label (`MPG` | `L/100KM`).
String economyUnitLabel(bool mpg) => mpg ? 'MPG' : 'L/100KM';
