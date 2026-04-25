// Cestovni `ThemeData` builders (CES-55).
//
// Maps Cestovni's semantic tokens (`CestovniColors`) onto Material 3
// `ColorScheme` slots so existing Material widgets render in the
// ledger/parchment language without per-widget overrides.
//
// First-load default is dark (see styling spec §1 + §5). Light is
// available for future user toggle.

import 'package:flutter/material.dart';

import 'cestovni_tokens.dart';
import 'cestovni_typography.dart';

class CestovniTheme {
  const CestovniTheme._();

  /// Dark mode `ThemeData` — first-load default.
  static ThemeData dark() => _build(CestovniColors.dark, Brightness.dark);

  /// Light mode `ThemeData`.
  static ThemeData light() => _build(CestovniColors.light, Brightness.light);

  static ThemeData _build(CestovniColors c, Brightness brightness) {
    // Map semantic tokens onto Material's ColorScheme. `surface` is
    // paper, `onSurface` is ink. Primary == ink so primary buttons
    // read as ink-fill / paper-text per styling spec §7.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.paper,
      secondary: c.accent,
      onSecondary: c.paper,
      tertiary: c.good,
      onTertiary: c.paper,
      error: c.destructive,
      onError: c.paper,
      surface: c.paper,
      onSurface: c.ink,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.card,
      surfaceContainerHighest: c.paperDeep,
      surfaceContainerLow: c.paperDeep,
      surfaceContainerLowest: c.paper,
      onSurfaceVariant: c.mutedForeground,
      outline: c.rule,
      outlineVariant: c.rule,
      shadow: c.ink,
      scrim: c.ink,
      inverseSurface: c.ink,
      onInverseSurface: c.paper,
      inversePrimary: c.paper,
    );

    final textTheme = CestovniTypography.textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      dividerColor: c.rule,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c],

      // AppBar — paper background, ink text/icons, hairline at bottom
      // is handled by the shell header treatment, not Material's
      // default scrim.
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: c.ink),
      ),

      // Bottom navigation — ink active, muted inactive, paper bg.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.paperDeep,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.ink
                : c.mutedForeground,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => CestovniTypography.labelMono(
            color: states.contains(WidgetState.selected)
                ? c.ink
                : c.mutedForeground,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.rule,
        thickness: CestovniMetrics.hairline,
        space: 0,
      ),

      // Cards — `card` surface, `radiusBase`, no Material elevation;
      // `LedgerCard` provides the hard offset shadow.
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.ink, width: CestovniMetrics.hairline),
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
        ),
      ),

      // Inputs — paper surface, ink border, mono fields.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CestovniMetrics.tilePadding,
          vertical: CestovniMetrics.tilePadding,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          borderSide:
              BorderSide(color: c.ink, width: CestovniMetrics.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          borderSide:
              BorderSide(color: c.ink, width: CestovniMetrics.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          borderSide: BorderSide(color: c.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          borderSide:
              BorderSide(color: c.destructive, width: CestovniMetrics.hairline),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.mutedForeground),
      ),

      // Primary CTA — ink fill, paper text, mono uppercase per §7.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.paper,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          ),
          textStyle: CestovniTypography.mono(
            fontSize: 13,
            color: c.paper,
            weight: FontWeight.w600,
            letterSpacing: 0.10 * 13,
          ),
        ),
      ),

      // Outline button — paper fill, ink border/text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.ink, width: CestovniMetrics.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
          ),
          textStyle: CestovniTypography.mono(
            fontSize: 13,
            color: c.ink,
            weight: FontWeight.w500,
            letterSpacing: 0.10 * 13,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: CestovniTypography.mono(
            fontSize: 13,
            color: c.ink,
            weight: FontWeight.w500,
          ),
        ),
      ),

      iconTheme: IconThemeData(color: c.ink, size: 22),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink,
        textColor: c.ink,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
      ),
    );
  }
}
