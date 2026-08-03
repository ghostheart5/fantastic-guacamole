import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('login screen golden', () {
    testWidgets('default state matches baseline', (WidgetTester tester) async {
      final TextEditingController email = TextEditingController(text: 'pilot@chronospark.app');
      final TextEditingController password = TextEditingController(text: 'secure-pass-123');
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            emailController: email,
            passwordController: password,
            obscurePassword: true,
            isSubmitting: false,
            isSignUpMode: false,
            onPrimaryAction: () {},
            onForgotPassword: () {},
            onGoogleSignIn: () {},
            onToggleMode: () {},
            onTogglePassword: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/auth/login_screen_default.png'),
      );
    });
  });
}
