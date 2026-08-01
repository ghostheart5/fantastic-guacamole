import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P1-4 creator-first navigation contract', () {
    test('router initial location logic prioritizes creator when onboarding is incomplete or first item is missing', () {
      final File file = File('lib/app/router/app_router.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(text.contains('if (!onboardingComplete) {'), isTrue);
      expect(text.contains('return isAuthenticated ? RoutePaths.creator : RoutePaths.onboarding;'), isTrue);
      expect(text.contains('if (!hasCreatedFirstItem) {'), isTrue);
      expect(text.contains('return RoutePaths.creator;'), isTrue);
    });

    test('navigation shell activation lock requires creator before first item is created', () {
      final File file = File('lib/app/navigation_shell.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(text.contains('if (onboardingStatus == OnboardingStatus.incomplete) {'), isTrue);
      expect(text.contains('return AppView.creator;'), isTrue);
      expect(text.contains('if (!hasCreatedFirstItem) {'), isTrue);
      expect(text.contains('return AppView.creator;'), isTrue);
      expect(text.contains('_enforceActivationView('), isTrue);
      expect(text.contains('widget.initialView'), isTrue);
    });
  });
}
