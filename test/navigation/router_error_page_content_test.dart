import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Router error page contract tests', () {
    test('home route remains distinct from special routes', () {
      expect(RoutePaths.home, isNot(RoutePaths.onboarding));
      expect(RoutePaths.home, isNot(RoutePaths.login));
      expect(RoutePaths.home, isNot(RoutePaths.settings));
      expect(RoutePaths.home, isNot(RoutePaths.paywall));
    });

    test('legal routes remain unique', () {
      expect(RoutePaths.privacy, isNot(RoutePaths.terms));
      expect(RoutePaths.support, isNot(RoutePaths.about));
      expect(RoutePaths.deleteAccount, isNot(RoutePaths.support));
    });

    test('notification routes remain nested correctly', () {
      expect(
        RoutePaths.notifications.startsWith('/settings'),
        isTrue,
      );

      expect(
        RoutePaths.notificationPermissionRecovery.startsWith(
          RoutePaths.notifications,
        ),
        isTrue,
      );
    });

    test('paywall subroutes remain unique', () {
      final routes = <String>{
        RoutePaths.paywall,
        RoutePaths.planComparison,
        RoutePaths.creditStore,
        RoutePaths.creditHistory,
        RoutePaths.subscriptionManagement,
      };

      expect(routes.length, 5);
    });

    test('root routes have expected format', () {
      final roots = <String>[
        RoutePaths.home,
        RoutePaths.plan,
        RoutePaths.creator,
        RoutePaths.insights,
        RoutePaths.settings,
        RoutePaths.paywall,
      ];

      for (final route in roots) {
        expect(route.startsWith('/'), isTrue);
        expect(route.length, greaterThan(1));
      }
    });
  });
}
