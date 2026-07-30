import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/ui/widgets/app_button.dart';
import 'package:fantastic_guacamole/ui/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('widget state coverage', () {
    testWidgets('login screen renders empty state with core controls', (
      WidgetTester tester,
    ) async {
      final TextEditingController email = TextEditingController();
      final TextEditingController password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      await tester.pumpWidget(
        _wrap(
          LoginScreen(
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
      await tester.pump();

      expect(find.text('ACCESS SYSTEM'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('login-email-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('login-password-field')),
        findsOneWidget,
      );
      expect(find.text('ENTER SYSTEM'), findsOneWidget);
    });

    testWidgets('login screen shows loading overlay when submitting', (
      WidgetTester tester,
    ) async {
      final TextEditingController email = TextEditingController();
      final TextEditingController password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      await tester.pumpWidget(
        _wrap(
          LoginScreen(
            emailController: email,
            passwordController: password,
            obscurePassword: true,
            isSubmitting: true,
            isSignUpMode: false,
            onPrimaryAction: () {},
            onForgotPassword: () {},
            onGoogleSignIn: () {},
            onToggleMode: () {},
            onTogglePassword: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('login screen shows startup error and actions are tappable', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int primaryTapCount = 0;
      int forgotTapCount = 0;

      final TextEditingController email = TextEditingController();
      final TextEditingController password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      await tester.pumpWidget(
        _wrap(
          LoginScreen(
            emailController: email,
            passwordController: password,
            obscurePassword: true,
            isSubmitting: false,
            isSignUpMode: false,
            startupError: 'Auth initialization failed.',
            onPrimaryAction: () => primaryTapCount += 1,
            onForgotPassword: () => forgotTapCount += 1,
            onGoogleSignIn: () {},
            onToggleMode: () {},
            onTogglePassword: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Auth initialization failed.'), findsOneWidget);

      await tester.tap(find.text('ENTER SYSTEM'));
      await tester.pump();
      await tester.tap(find.text('Forgot Password?'));
      await tester.pump();

      expect(primaryTapCount, 1);
      expect(forgotTapCount, 1);
    });

    testWidgets('login screen has no GitHub sign-in action', (
      WidgetTester tester,
    ) async {
      final TextEditingController email = TextEditingController();
      final TextEditingController password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      await tester.pumpWidget(
        _wrap(
          LoginScreen(
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
      await tester.pump();

      expect(find.textContaining('GitHub', findRichText: true), findsNothing);
    });

    testWidgets('error and ready widgets expose expected states', (
      WidgetTester tester,
    ) async {
      int retryCount = 0;
      int actionCount = 0;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: <Widget>[
              ErrorView(
                title: 'Error title',
                message: 'Unable to load timeline.',
                onRetry: () => retryCount += 1,
              ),
              AppButton(label: 'Try again', onPressed: () => actionCount += 1),
            ],
          ),
        ),
      );

      expect(find.text('Error title'), findsOneWidget);
      expect(find.text('Unable to load timeline.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retryCount, 1);
      expect(actionCount, 1);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
