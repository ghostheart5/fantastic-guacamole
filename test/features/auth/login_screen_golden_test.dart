import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    addTearDown(emailController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
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
      ),
    );
    await tester.pump();
    // LoginScreen's entry animation runs for 720ms before the responsive text
    // reaches its final painted position and style.
    await tester.pump(const Duration(milliseconds: 800));
  }

  Text textWidget(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text).first);

  group('LoginScreen responsive typography', () {
    testWidgets('uses compact values below the compact breakpoint', (
      WidgetTester tester,
    ) async {
      await pumpLoginScreen(tester, width: Breakpoints.compact - 1);

      expect(
        textWidget(tester, 'TEMPORAL INTELLIGENCE SYSTEM').style?.fontSize,
        AppSizes.fontXs,
      );
      expect(
        textWidget(tester, 'ACCESS SYSTEM').style?.fontSize,
        AppSizes.fontXs,
      );
      expect(
        textWidget(
          tester,
          'Secure access to your connected planning workspace.',
        ).style?.fontSize,
        AppSizes.fontCaption,
      );

      final TextField emailField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('login-email-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(emailField.style?.fontSize, AppSizes.fontLabel);
      expect(emailField.decoration?.hintStyle?.fontSize, AppSizes.fontLabel);
    });

    testWidgets('uses regular values at the compact breakpoint', (
      WidgetTester tester,
    ) async {
      await pumpLoginScreen(tester, width: Breakpoints.compact);

      expect(
        textWidget(tester, 'TEMPORAL INTELLIGENCE SYSTEM').style?.fontSize,
        AppSizes.fontSm,
      );
      expect(
        textWidget(tester, 'ACCESS SYSTEM').style?.fontSize,
        AppSizes.fontSm,
      );
      expect(
        textWidget(
          tester,
          'Secure access to your connected planning workspace.',
        ).style?.fontSize,
        AppSizes.fontBody,
      );
    });
  });
}
