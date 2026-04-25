// Cestovni typography (CES-55).
//
// Source of truth: `docs/product/ux/cestovni-styling.md` §2.
//
// - Serif (Fraunces 600, tracking -0.01em) — page titles, headlines,
//   large numerals.
// - Sans (Inter) — body copy, descriptions, form labels.
// - Mono (JetBrains Mono) — labels, pills, button text, numeric data.
// - `labelMono` token — uppercase, 0.12em tracking, ~11sp,
//   muted-foreground; the workhorse meta label.
//
// Fonts are loaded via `google_fonts` (see pubspec.yaml deviation
// note). Switch to bundled assets in Stage 6 polish.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cestovni_tokens.dart';

class CestovniTypography {
  const CestovniTypography._();

  /// When `false`, font helpers return a plain `TextStyle` with
  /// `fontFamily` set to a CSS-style fallback name instead of
  /// invoking `google_fonts`. Tests flip this off so theme
  /// construction does not trigger async network fetches that the
  /// test framework would otherwise report as uncaught errors.
  static bool useGoogleFonts = true;

  /// Serif (Fraunces) base style. `weight = 600`, `letterSpacing`
  /// approximated to `-0.01em` at the relevant font size.
  static TextStyle serif({
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) {
    final letterSpacing = -0.01 * fontSize;
    if (!useGoogleFonts) {
      return TextStyle(
        fontFamily: 'Fraunces',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Sans (Inter) base style.
  static TextStyle sans({
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Helvetica', 'Arial', 'sans-serif'],
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  /// Mono (JetBrains Mono) base style.
  static TextStyle mono({
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const ['IBM Plex Mono', 'monospace'],
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// `labelMono` workhorse meta label per styling spec §2.
  /// Uppercase + 0.12em tracking is enforced at the call site (the
  /// `Text` widget uppercases content). This style only carries the
  /// font, size, weight, tracking, and colour.
  static TextStyle labelMono({required Color color}) {
    const fontSize = 11.0;
    return mono(
      fontSize: fontSize,
      color: color,
      weight: FontWeight.w500,
      letterSpacing: 0.12 * fontSize,
    );
  }

  /// Build a Material `TextTheme` from semantic tokens. `colors.ink`
  /// is the default foreground; `mutedForeground` is for secondary
  /// styles. Display/headline use Fraunces; titles/body use Inter;
  /// labels use JetBrains Mono.
  static TextTheme textTheme(CestovniColors colors) {
    final ink = colors.ink;
    final muted = colors.mutedForeground;

    return TextTheme(
      // Hero numerals (lifetime totals, big metric values).
      displayLarge: serif(fontSize: 56, color: ink, height: 1.0),
      displayMedium: serif(fontSize: 44, color: ink, height: 1.05),
      displaySmall: serif(fontSize: 32, color: ink, height: 1.1),

      // Page titles, card headlines.
      headlineLarge: serif(fontSize: 28, color: ink),
      headlineMedium: serif(fontSize: 24, color: ink),
      headlineSmall: serif(fontSize: 20, color: ink),

      // Section titles, card titles — sans for editorial body.
      titleLarge: sans(fontSize: 18, color: ink, weight: FontWeight.w600),
      titleMedium: sans(fontSize: 16, color: ink, weight: FontWeight.w600),
      titleSmall: sans(fontSize: 14, color: ink, weight: FontWeight.w600),

      // Body copy.
      bodyLarge: sans(fontSize: 16, color: ink, height: 1.4),
      bodyMedium: sans(fontSize: 14, color: ink, height: 1.4),
      bodySmall: sans(fontSize: 12, color: muted, height: 1.4),

      // Labels — primary and `labelMono`.
      labelLarge: mono(
        fontSize: 13,
        color: ink,
        weight: FontWeight.w500,
        letterSpacing: 0.06,
      ),
      labelMedium: mono(
        fontSize: 12,
        color: ink,
        weight: FontWeight.w500,
        letterSpacing: 0.08,
      ),
      labelSmall: labelMono(color: muted),
    );
  }
}
