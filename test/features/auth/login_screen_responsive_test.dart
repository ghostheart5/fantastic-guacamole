import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login surface remains usable at 1280x720', (
    WidgetTester tester,
  ) async {
    final TextEditingController email = TextEditingController(
      text: 'pilot@chronospark.app',
    );
    final TextEditingController password = TextEditingController(
      text: 'secure-pass-123',
    );
    addTearDown(email.dispose);
    addTearDown(password.dispose);

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    int primaryActions = 0;
    int passwordResets = 0;
    int googleSignIns = 0;
    int modeToggles = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          emailController: email,
          passwordController: password,
          obscurePassword: true,
          isSubmitting: false,
          isSignUpMode: false,
          onPrimaryAction: () => primaryActions += 1,
          onForgotPassword: () => passwordResets += 1,
          onGoogleSignIn: () => googleSignIns += 1,
          onToggleMode: () => modeToggles += 1,
          onTogglePassword: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(find.text('ACCESS SYSTEM'), findsOneWidget);
    expect(find.text('ENTER SYSTEM'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    final Rect formBounds = tester.getRect(
      find.byKey(const ValueKey('login-email-field')),
    );
    expect(formBounds.left, greaterThanOrEqualTo(0));
    expect(formBounds.right, lessThanOrEqualTo(1280));
    expect(formBounds.top, greaterThanOrEqualTo(0));
    expect(formBounds.bottom, lessThanOrEqualTo(720));

    await tester.tap(find.text('ENTER SYSTEM'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text('Create account'));

    expect(primaryActions, 1);
    expect(passwordResets, 1);
    expect(googleSignIns, 1);
    expect(modeToggles, 1);
  });
}
