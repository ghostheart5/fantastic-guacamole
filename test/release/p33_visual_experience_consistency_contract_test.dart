import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P3-3 visual experience consistency contract', () {
    test('app theme keeps dual-mode material3 and Inter typography anchors', () {
      final File appThemeFile = File('lib/theme/app_theme.dart');
      expect(appThemeFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(appThemeFile);

      expect(text.contains('final ThemeData appTheme = ThemeData('), isTrue);
      expect(text.contains('final ThemeData appLightTheme = ThemeData('), isTrue);
      expect(
        SourceTestUtils.countMatches(text, RegExp(r'useMaterial3:\s*true')),
        greaterThanOrEqualTo(2),
      );
      expect(
        SourceTestUtils.countMatches(text, RegExp(r"fontFamily:\s*'Inter'")),
        greaterThanOrEqualTo(2),
      );
      expect(text.contains('extensions: const <ThemeExtension<dynamic>>[defaultNeonEffects],'), isTrue);
    });

    test('theme color system keeps neon signature tokens and gradients', () {
      final File colorsFile = File('lib/theme/colors.dart');
      expect(colorsFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(colorsFile);

      expect(text.contains('const Color neonCyan = Color(0xFF00E5FF);'), isTrue);
      expect(text.contains('const Color neonViolet = Color(0xFF9A4DFF);'), isTrue);
      expect(text.contains('const Color neonMagenta = Color(0xFFFF2EC4);'), isTrue);
      expect(text.contains('const LinearGradient cosmicGradient = LinearGradient('), isTrue);
      expect(text.contains('const LinearGradient neonPulseGradient = LinearGradient('), isTrue);
      expect(text.contains('const LinearGradient glassPanelGradient = LinearGradient('), isTrue);
    });

    test('typography and ui color constants retain readability hierarchy aliases', () {
      final File typographyFile = File('lib/theme/typography.dart');
      final File uiColorsFile = File('lib/ui/constants/app_colors.dart');
      expect(typographyFile.existsSync(), isTrue);
      expect(uiColorsFile.existsSync(), isTrue);

      final String typographyText = SourceTestUtils.readText(typographyFile);
      final String uiColorsText = SourceTestUtils.readText(uiColorsFile);

      expect(typographyText.contains('final TextTheme neonTextTheme ='), isTrue);
      expect(typographyText.contains('headlineLarge'), isTrue);
      expect(typographyText.contains('headlineMedium'), isTrue);
      expect(typographyText.contains('bodyLarge'), isTrue);
      expect(typographyText.contains('labelLarge'), isTrue);

      expect(uiColorsText.contains('static const textPrimary = Colors.white;'), isTrue);
      expect(uiColorsText.contains('static const textSecondary = Colors.white70;'), isTrue);
      expect(uiColorsText.contains('static const textMuted = Color(0xFFB6AEC4);'), isTrue);
      expect(uiColorsText.contains('static const textDim = Color(0xFF8C839E);'), isTrue);
      expect(uiColorsText.contains('static const bgPrimary = background;'), isTrue);
      expect(uiColorsText.contains('static const neonCyan = Color(0xFF00E5FF);'), isTrue);
      expect(uiColorsText.contains('static const neonViolet = Color(0xFF9B8AFB);'), isTrue);
    });
  });
}
