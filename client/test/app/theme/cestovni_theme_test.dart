import 'package:cestovni/app/theme/cestovni_primitives.dart';
import 'package:cestovni/app/theme/cestovni_theme.dart';
import 'package:cestovni/app/theme/cestovni_tokens.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CES-55 smoke tests — theme builders construct without error,
/// expose `CestovniColors` via `ThemeExtension`, and the Material
/// `ColorScheme` is wired to the semantic tokens (paper -> surface,
/// ink -> onSurface).
void main() {
  setUpAll(() {
    // Tests must not hit the network. Disable google_fonts so theme
    // construction returns plain `TextStyle`s with `fontFamily` set.
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  group('CestovniTheme', () {
    test('dark() builds and exposes CestovniColors.dark', () {
      final theme = CestovniTheme.dark();
      expect(theme.brightness, Brightness.dark);

      final colors = theme.extension<CestovniColors>();
      expect(colors, isNotNull);
      expect(colors!.paper, CestovniColors.dark.paper);
      expect(colors.ink, CestovniColors.dark.ink);
      expect(colors.accent, CestovniColors.dark.accent);

      expect(theme.colorScheme.surface, colors.paper);
      expect(theme.colorScheme.onSurface, colors.ink);
      expect(theme.colorScheme.outline, colors.rule);
      expect(theme.scaffoldBackgroundColor, colors.paper);
    });

    test('light() builds and exposes CestovniColors.light', () {
      final theme = CestovniTheme.light();
      expect(theme.brightness, Brightness.light);

      final colors = theme.extension<CestovniColors>();
      expect(colors, isNotNull);
      expect(colors!.paper, CestovniColors.light.paper);
      expect(colors.ink, CestovniColors.light.ink);
    });

    test('TextTheme is populated with semantic styles', () {
      final theme = CestovniTheme.dark();
      // Display + headlines must be set (Fraunces serif).
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.headlineMedium, isNotNull);
      // Body + label must be set.
      expect(theme.textTheme.bodyMedium, isNotNull);
      expect(theme.textTheme.labelSmall, isNotNull);
      // labelMono token uses muted-foreground.
      expect(theme.textTheme.labelSmall!.color,
          CestovniColors.dark.mutedForeground);
    });
  });

  group('CestovniColors lerp', () {
    test('lerp at 0 returns this; at 1 returns other', () {
      final result0 = CestovniColors.dark.lerp(CestovniColors.light, 0);
      final result1 = CestovniColors.dark.lerp(CestovniColors.light, 1);
      expect(result0.paper, CestovniColors.dark.paper);
      expect(result1.paper, CestovniColors.light.paper);
    });
  });

  group('Primitives', () {
    testWidgets('LedgerCard, LedgerTile, HairlineDivider render under theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CestovniTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                LedgerCard(child: Text('card')),
                LedgerTile(child: Text('tile')),
                HairlineDivider(),
              ],
            ),
          ),
        ),
      );
      // Allow google_fonts async loads to settle without network.
      await tester.pump();

      expect(find.text('card'), findsOneWidget);
      expect(find.text('tile'), findsOneWidget);
      expect(find.byType(HairlineDivider), findsOneWidget);
    });
  });

  group('CestovniTypography labelMono', () {
    test('labelMono returns muted-foreground style with tracking', () {
      final style = CestovniTypography.labelMono(
        color: CestovniColors.dark.mutedForeground,
      );
      expect(style.color, CestovniColors.dark.mutedForeground);
      expect(style.letterSpacing, isNotNull);
      expect(style.letterSpacing! > 0, isTrue);
      expect(style.fontSize, 11);
    });
  });
}
