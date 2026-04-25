// Cestovni semantic design tokens (CES-55).
//
// Source of truth: `docs/product/ux/cestovni-styling.md` §4–§6.
// OKLCH values in the spec are authoritative; the sRGB hex
// approximations below are what Flutter's `Color()` accepts. When
// regenerating tokens, copy the `≈ Hex` column from the styling spec.

import 'package:flutter/material.dart';

/// Semantic color roles used across the app. Stored as a Flutter
/// `ThemeExtension` so widgets can read tokens through
/// `Theme.of(context).extension<CestovniColors>()` without touching
/// raw hex.
@immutable
class CestovniColors extends ThemeExtension<CestovniColors> {
  const CestovniColors({
    required this.paper,
    required this.paperDeep,
    required this.card,
    required this.ink,
    required this.rule,
    required this.mutedForeground,
    required this.accent,
    required this.good,
    required this.warn,
    required this.destructive,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
  });

  /// Background surfaces. `paper` is the screen background; `card`
  /// the primary content surface; `paperDeep` the inset/tile fill.
  final Color paper;
  final Color paperDeep;
  final Color card;

  /// `ink` is the high-contrast mark on paper — text, borders, and
  /// primary fills. In dark mode this is **cream**, not black; never
  /// hardcode literal black/white for primary foreground.
  final Color ink;

  /// `rule` separates sections via 1px hairlines.
  final Color rule;

  /// Subtitle / mono micro-label colour.
  final Color mutedForeground;

  /// Burnt-orange accent for chart highlights and `MAINT` pills.
  final Color accent;

  /// Positive deltas.
  final Color good;

  /// Reminders and partial-fill pill.
  final Color warn;

  /// Delete actions only.
  final Color destructive;

  /// Chart palette — `chart1` is `ink`, `chart2` is `accent`, etc.
  /// Kept as discrete fields so chart widgets can reference them by
  /// position without colour-swatch drift.
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  /// Light palette — see styling spec §4.
  static const CestovniColors light = CestovniColors(
    paper: Color(0xFFF1EAD7),
    paperDeep: Color(0xFFE5DCC4),
    card: Color(0xFFF7F2E3),
    ink: Color(0xFF2A2620),
    rule: Color(0xFF574F45),
    mutedForeground: Color(0xFF6B6157),
    accent: Color(0xFFD2733A),
    good: Color(0xFF4F8C5A),
    warn: Color(0xFFD9A23A),
    destructive: Color(0xFFC5321F),
    chart1: Color(0xFF2A2620),
    chart2: Color(0xFFD2733A),
    chart3: Color(0xFF4F8C5A),
    chart4: Color(0xFFD9A23A),
    chart5: Color(0xFF4861A0),
  );

  /// Dark palette — see styling spec §5. Default first-load theme.
  static const CestovniColors dark = CestovniColors(
    paper: Color(0xFF1F1B16),
    paperDeep: Color(0xFF2D2922),
    card: Color(0xFF28241E),
    ink: Color(0xFFECE3CD),
    rule: Color(0xFF8B8278),
    mutedForeground: Color(0xFFB3AB9F),
    accent: Color(0xFFE68A4F),
    good: Color(0xFF4F8C5A),
    warn: Color(0xFFD9A23A),
    destructive: Color(0xFFDA4530),
    chart1: Color(0xFFECE3CD),
    chart2: Color(0xFFE68A4F),
    chart3: Color(0xFF4F8C5A),
    chart4: Color(0xFFD9A23A),
    chart5: Color(0xFF6B86C5),
  );

  @override
  CestovniColors copyWith({
    Color? paper,
    Color? paperDeep,
    Color? card,
    Color? ink,
    Color? rule,
    Color? mutedForeground,
    Color? accent,
    Color? good,
    Color? warn,
    Color? destructive,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
  }) {
    return CestovniColors(
      paper: paper ?? this.paper,
      paperDeep: paperDeep ?? this.paperDeep,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      rule: rule ?? this.rule,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      good: good ?? this.good,
      warn: warn ?? this.warn,
      destructive: destructive ?? this.destructive,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
    );
  }

  @override
  CestovniColors lerp(ThemeExtension<CestovniColors>? other, double t) {
    if (other is! CestovniColors) return this;
    return CestovniColors(
      paper: Color.lerp(paper, other.paper, t)!,
      paperDeep: Color.lerp(paperDeep, other.paperDeep, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      mutedForeground:
          Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chart5: Color.lerp(chart5, other.chart5, t)!,
    );
  }
}

/// Spacing, radius, and stroke constants from styling spec §3 / §6.
/// Use these everywhere instead of magic numbers.
class CestovniMetrics {
  const CestovniMetrics._();

  /// Base corner radius (cards, tiles, inputs, buttons).
  static const double radiusBase = 6;

  /// Smaller radii — `radiusXs` for micro pills, `radiusSm` for
  /// secondary surfaces.
  static const double radiusXs = 2;
  static const double radiusSm = 4;

  /// Larger card radius.
  static const double radiusLg = 10;

  /// Hairline / border stroke width (`1px ink`).
  static const double hairline = 1;

  /// Hard offset shadow used by `LedgerCard` (no blur).
  static const Offset cardShadowOffset = Offset(3, 3);

  /// Tile padding (`12dp`).
  static const double tilePadding = 12;

  /// Card padding (`24dp`).
  static const double cardPadding = 24;

  /// Page horizontal padding.
  static const double pagePadding = 16;

  /// Section rhythm — gap between major blocks.
  static const double sectionGap = 24;

  /// Centered content max width on tablet/desktop.
  static const double contentMaxWidth = 672;
}

/// Convenience accessor for the current theme's `CestovniColors`. Use
/// inside `build` methods: `final c = context.cestovniColors;`. Falls
/// back to the dark palette if the extension is missing so widgets
/// keep rendering during smoke tests with a bare `ThemeData()`.
extension CestovniColorsContext on BuildContext {
  CestovniColors get cestovniColors {
    final theme = Theme.of(this);
    return theme.extension<CestovniColors>() ?? CestovniColors.dark;
  }
}
