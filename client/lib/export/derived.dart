/// Canonical → CSV derived-column conversions (CES-41).
///
/// Spec: `docs/specs/si-units.md` display rounding + `export-v1.md` § A2
/// (both unit columns always ship). CSV values have **no** thousands
/// separators so spreadsheet tools parse them as numbers.
library;

import '../consumption/rounding.dart';
import '../units/display_units.dart';

/// Canonical meters → whole km (0 decimals, banker's). Null stays null.
String? metersToKmCsv(int? meters) =>
    meters == null ? null : metersToDisplayWhole(meters, 'km').toString();

/// Canonical meters → whole mi (0 decimals, banker's). Null stays null.
String? metersToMiCsv(int? meters) =>
    meters == null ? null : metersToDisplayWhole(meters, 'mi').toString();

/// Canonical µL → litres with 2 decimals, no grouping.
String? volumeToLitersCsv(int? microliters) =>
    microliters == null ? null : _volumeCsv(microliters, microlitersPerLiter);

/// Canonical µL → US gallons with 2 decimals, no grouping.
String? volumeToGallonsCsv(int? microliters) => microliters == null
    ? null
    : _volumeCsv(microliters, microlitersPerUsGallon);

/// Canonical cents → major units with 2 decimals, no grouping.
String centsToMajorCsv(int cents) {
  final String sign = cents < 0 ? '-' : '';
  final int abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

String _volumeCsv(int microliters, int perUnit) {
  final int scaled = divideRoundHalfEven(microliters * 100, perUnit);
  final String sign = scaled < 0 ? '-' : '';
  final int abs = scaled.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}
