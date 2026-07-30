import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('route and action hub coverage', () {
    test('public route constants are non-empty and normalized', () {
      final List<String> primary = <String>[
        RoutePaths.home,
        RoutePaths.plan,
        RoutePaths.creator,
        RoutePaths.insights,
        RoutePaths.settings,
        RoutePaths.notifications,
        RoutePaths.timeline,
        RoutePaths.profile,
        RoutePaths.progression,
        RoutePaths.si,
        RoutePaths.advisor,
      ];

      for (final String route in primary) {
        expect(route, isNotEmpty);
        expect(route.startsWith('/'), isTrue);
        expect(route.contains('//'), isFalse);
      }

      expect(RoutePaths.legacyCoach, '/coach');
      expect(RoutePaths.legacyTimeline, '/logs');
      expect(RoutePaths.legacyNotifications, '/notifications');
    });

    test('route surface provider exposes user-visible destinations', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RouteSurface surface = container.read(routeSurfaceProvider);
      expect(surface.login, RoutePaths.login);
      expect(surface.onboarding, RoutePaths.onboarding);
      expect(surface.support, RoutePaths.support);
      expect(surface.notifications, RoutePaths.notifications);
      expect(
        surface.notificationPermissionRecovery,
        RoutePaths.notificationPermissionRecovery,
      );
    });

    testWidgets(
      'login actions expose labels and callbacks without GitHub action',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        int googleTaps = 0;
        final TextEditingController email = TextEditingController();
        final TextEditingController password = TextEditingController();
        addTearDown(email.dispose);
        addTearDown(password.dispose);

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
              onGoogleSignIn: () => googleTaps += 1,
              onToggleMode: () {},
              onTogglePassword: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Use Phone Login'), findsNothing);
        expect(find.textContaining('GitHub', findRichText: true), findsNothing);

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        expect(googleTaps, 1);
      },
    );
  });
}
