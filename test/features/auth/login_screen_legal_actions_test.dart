import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const ValueKey<String> privacyKey = ValueKey<String>('login-privacy-action');
  const ValueKey<String> termsKey = ValueKey<String>('login-terms-action');

  testWidgets(
    'shows accessible legal actions before account creation and OAuth',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      final _LoginHarness harness = await _pumpLoginRouter(
        tester,
        initialLocation: RoutePaths.login,
        isSignUpMode: true,
      );
      addTearDown(harness.dispose);

      final Finder privacyAction = find.byKey(privacyKey);
      final Finder termsAction = find.byKey(termsKey);
      final Finder primaryAction = find.text('INITIALIZE PROFILE');
      final Finder googleAction = find.text('Continue with Google');
      final Finder githubAction = find.text('Continue with GitHub');

      expect(privacyAction, findsOneWidget);
      expect(termsAction, findsOneWidget);
      expect(find.bySemanticsLabel('Open Privacy Policy'), findsOneWidget);
      expect(find.bySemanticsLabel('Open Terms of Service'), findsOneWidget);
      expect(privacyAction.hitTestable(), findsOneWidget);
      expect(termsAction.hitTestable(), findsOneWidget);
      expect(tester.getSize(privacyAction).height, AppSizes.touchTarget);
      expect(tester.getSize(termsAction).height, AppSizes.touchTarget);

      final double legalBottom = tester.getRect(privacyAction).bottom;
      expect(legalBottom, lessThan(tester.getRect(primaryAction).top));
      expect(legalBottom, lessThan(tester.getRect(googleAction).top));
      expect(legalBottom, lessThan(tester.getRect(githubAction).top));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('legal routes preserve login returnTo and back navigation', (
    WidgetTester tester,
  ) async {
    const String returnTo = '/timeline?day=2026-08-29#block-7';
    final String initialLocation = Uri(
      path: RoutePaths.login,
      queryParameters: <String, String>{'returnTo': returnTo},
    ).toString();
    final _LoginHarness harness = await _pumpLoginRouter(
      tester,
      initialLocation: initialLocation,
    );
    addTearDown(harness.dispose);

    for (final ({String label, String path, String destination}) expectation
        in <({String label, String path, String destination})>[
          (
            label: 'Privacy',
            path: RoutePaths.privacy,
            destination: 'Privacy destination',
          ),
          (
            label: 'Terms',
            path: RoutePaths.terms,
            destination: 'Terms destination',
          ),
        ]) {
      final Finder action = find.text(expectation.label).hitTestable();
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(expectation.destination), findsOneWidget);
      expect(harness.router.state.uri.path, expectation.path);
      expect(harness.router.canPop(), isTrue);

      harness.router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final Uri restored = harness.router.routeInformationProvider.value.uri;
      expect(restored.path, RoutePaths.login);
      expect(restored.queryParameters['returnTo'], returnTo);
      expect(find.text(expectation.label), findsOneWidget);
    }
  });
}

Future<_LoginHarness> _pumpLoginRouter(
  WidgetTester tester, {
  required String initialLocation,
  bool isSignUpMode = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) => LoginScreen(
          emailController: emailController,
          passwordController: passwordController,
          obscurePassword: true,
          isSubmitting: false,
          isSignUpMode: isSignUpMode,
          onPrimaryAction: () {},
          onForgotPassword: () {},
          onGoogleSignIn: () {},
          onGitHubSignIn: () {},
          onToggleMode: () {},
          onTogglePassword: () {},
        ),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Privacy destination'))),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Terms destination'))),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));

  return _LoginHarness(
    router: router,
    emailController: emailController,
    passwordController: passwordController,
  );
}

class _LoginHarness {
  const _LoginHarness({
    required this.router,
    required this.emailController,
    required this.passwordController,
  });

  final GoRouter router;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  void dispose() {
    router.dispose();
    emailController.dispose();
    passwordController.dispose();
  }
}
