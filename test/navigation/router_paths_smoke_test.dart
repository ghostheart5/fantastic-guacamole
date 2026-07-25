import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutePaths smoke tests', () {
    test('all route constants are unique', () {
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
        RoutePaths.legacyCoach,
        RoutePaths.legacyLogs,
        RoutePaths.legacyNotifications,
        RoutePaths.legacyProgression,
        RoutePaths.legacySi,
        RoutePaths.legacyTasks,
        RoutePaths.legacyProfile,
      ];

      expect(routes.length, routes.toSet().length);
    });

    test('all routes begin with slash', () {
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
        RoutePaths.legacyCoach,
        RoutePaths.legacyLogs,
        RoutePaths.legacyNotifications,
        RoutePaths.legacyProgression,
        RoutePaths.legacySi,
        RoutePaths.legacyTasks,
        RoutePaths.legacyProfile,
      ];

      for (final route in routes) {
        expect(route.startsWith('/'), isTrue);
      }
    });

    test('advanced routes remain under advanced root', () {
      expect(RoutePaths.logs.startsWith(RoutePaths.advancedRoot), isTrue);
      expect(RoutePaths.tasks.startsWith(RoutePaths.advancedRoot), isTrue);
      expect(RoutePaths.profile.startsWith(RoutePaths.advancedRoot), isTrue);
      expect(RoutePaths.progression.startsWith(RoutePaths.advancedRoot), isTrue);
      expect(RoutePaths.si.startsWith(RoutePaths.advancedRoot), isTrue);
      expect(RoutePaths.advisor.startsWith(RoutePaths.advancedRoot), isTrue);
    });

    test('paywall routes remain grouped under paywall root', () {
      expect(
        RoutePaths.planComparison.startsWith(RoutePaths.paywall),
        isTrue,
      );

      expect(
        RoutePaths.creditStore.startsWith(RoutePaths.paywall),
        isTrue,
      );

      expect(
        RoutePaths.creditHistory.startsWith(RoutePaths.paywall),
        isTrue,
      );

      expect(
        RoutePaths.subscriptionManagement.startsWith(RoutePaths.paywall),
        isTrue,
      );
    });
  });
}