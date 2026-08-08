import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/golden_harness.dart';

/// Pixel regression coverage for Phase 6's M-1 font/breakpoint migration.
/// Generated against the CURRENT (pre-migration) screen first, then re-run
/// unchanged after the migration to prove it was value-preserving.
void main() {
  setUpAll(loadAppFontsForGolden);
  setUpAll(useTolerantGoldenComparator);

  for (final (String label, double width) in <(String, double)>[
    ('compact_320', 320),
    ('regular_500', 500),
  ]) {
    testWidgets('LoginScreen at $label matches golden', (
      WidgetTester tester,
    ) async {
      final TextEditingController emailController = TextEditingController();
      final TextEditingController passwordController =
          TextEditingController();
      addTearDown(emailController.dispose);
      addTearDown(passwordController.dispose);

      await pumpForGolden(
        tester,
        LoginScreen(
          emailController: emailController,
          passwordController: passwordController,
          obscurePassword: true,
          isSubmitting: false,
          isSignUpMode: false,
          onPrimaryAction: () {},
          onForgotPassword: () {},
          onGoogleSignIn: () {},
          onGitHubSignIn: () {},
          onToggleMode: () {},
          onTogglePassword: () {},
        ),
        size: Size(width, 900),
      );
      await tester.pump(const Duration(milliseconds: 800));

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_$label.png'),
      );
    });
  }
}
