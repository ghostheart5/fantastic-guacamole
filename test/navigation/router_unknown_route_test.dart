import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unknown route safety audit', () {
    test('unknown route string is not a known route', () {
      const String unknownRoute = '/definitely-not-a-real-route';

      final Set<String> knownRoutes = <String>{
        RoutePaths.shell,
        RoutePaths.onboarding,
        RoutePaths.login,
        RoutePaths.home,
        RoutePaths.plan,
        RoutePaths.creator,
        RoutePaths.insights,
        RoutePaths.settings,
        RoutePaths.notifications,
        RoutePaths.notificationPermissionRecovery,
        RoutePaths.advancedRoot,
        RoutePaths.logs,
        RoutePaths.tasks,
        RoutePaths.profile,
        RoutePaths.progression,
        RoutePaths.si,
        RoutePaths.advisor,
        RoutePaths.paywall,
        RoutePaths.planComparison,
        RoutePaths.creditStore,
        RoutePaths.creditHistory,
        RoutePaths.subscriptionManagement,
        RoutePaths.privacy,
        RoutePaths.deleteAccount,
        RoutePaths.terms,
        RoutePaths.support,
        RoutePaths.about,
      };

      expect(
        knownRoutes.contains(unknownRoute),
        isFalse,
      );
    });

    test('legacy routes remain distinct from modern routes', () {
      expect(RoutePaths.legacyCoach, isNot(RoutePaths.home));
      expect(RoutePaths.legacyLogs, isNot(RoutePaths.logs));
      expect(RoutePaths.legacyTasks, isNot(RoutePaths.tasks));
      expect(RoutePaths.legacyProfile, isNot(RoutePaths.profile));
      expect(RoutePaths.legacyProgression, isNot(RoutePaths.progression));
      expect(RoutePaths.legacyNotifications, isNot(RoutePaths.notifications));
      expect(RoutePaths.legacySi, isNot(RoutePaths.si));
    });

    test('route path strings are non-empty', () {
      final routes = <String>[
        RoutePaths.shell,
        RoutePaths.onboarding,
        RoutePaths.login,
        RoutePaths.home,
        RoutePaths.plan,
        RoutePaths.creator,
        RoutePaths.insights,
        RoutePaths.settings,
        RoutePaths.notifications,
        RoutePaths.notificationPermissionRecovery,
        RoutePaths.logs,
        RoutePaths.tasks,
        RoutePaths.profile,
        RoutePaths.progression,
        RoutePaths.si,
        RoutePaths.advisor,
        RoutePaths.paywall,
        RoutePaths.planComparison,
        RoutePaths.creditStore,
        RoutePaths.creditHistory,
        RoutePaths.subscriptionManagement,
        RoutePaths.privacy,
        RoutePaths.deleteAccount,
        RoutePaths.terms,
        RoutePaths.support,
        RoutePaths.about,
      ];

      for (final route in routes) {
        expect(route.trim(), isNotEmpty);
      }
    });
  });
}
