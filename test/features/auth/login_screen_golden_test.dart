import 'dart:ui' show SemanticsFlag;

import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required double width,
    double height = 900,
    bool obscurePassword = true,
    VoidCallback? onPrimaryAction,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    addTearDown(emailController.dispose);
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: LoginScreen(
              emailController: emailController,
              passwordController: passwordController,
              obscurePassword: obscurePassword,
              isSubmitting: false,
              isSignUpMode: false,
              onPrimaryAction: onPrimaryAction ?? () {},
              onForgotPassword: () {},
              onGoogleSignIn: () {},
              onGitHubSignIn: () {},
              onPrivacyPolicy: () {},
              onTermsOfService: () {},
              onToggleMode: () {},
              onTogglePassword: () {},
            ),
          ),
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

  testWidgets('keeps the login surface usable at 1280x720', (
    WidgetTester tester,
  ) async {
    int primaryActionCalls = 0;

    await pumpLoginScreen(
      tester,
      width: 1280,
      height: 720,
      onPrimaryAction: () => primaryActionCalls += 1,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(find.text('ENTER SYSTEM'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with GitHub'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    for (final Key key in const <Key>[
      ValueKey('login-email-field'),
      ValueKey('login-password-field'),
    ]) {
      final Rect rect = tester.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(1280));
    }

    final Finder primaryAction = find.text('ENTER SYSTEM');
    expect(primaryAction.hitTestable(), findsOneWidget);
    await tester.tap(primaryAction);
    await tester.pump();

    expect(primaryActionCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('names login fields and the password visibility action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpLoginScreen(tester, width: 420);

    expect(find.bySemanticsLabel(RegExp(r'^Email field\b')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Password field\b')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp(r'^Email field\b')))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isTextField),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp(r'^Password field\b')))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isTextField),
      isTrue,
    );
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide password'), findsNothing);

    await pumpLoginScreen(tester, width: 420, obscurePassword: false);

    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(find.bySemanticsLabel('Show password'), findsNothing);
    semantics.dispose();
  });

  testWidgets('does not keep login animations running under reduced motion', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(
      tester,
      width: 420,
      height: 900,
      disableAnimations: true,
    );

    expect(tester.hasRunningAnimations, isFalse);
  });
}
