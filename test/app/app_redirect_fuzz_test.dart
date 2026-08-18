import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies [computeAppRedirect] repeatedly, mirroring go_router's own
/// redirect loop (capped at its `redirectLimit` of 5), and returns the
/// stable location once a call returns null. Returns null if it never
/// stabilizes within the limit — the same condition that trips go_router's
/// `TooManyRedirectsException` in the real app.
String? _followToStableLocation({
  required bool isAuthenticated,
  required bool onboardingComplete,
  required bool mockLoginEnabled,
  required String location,
}) {
  String current = location;
  for (int i = 0; i < 5; i++) {
    final String? next = computeAppRedirect(
      isAuthenticated: isAuthenticated,
      onboardingComplete: onboardingComplete,
      mockLoginEnabled: mockLoginEnabled,
      location: current,
    );
    if (next == null) {
      return current;
    }
    current = next;
  }
  return null;
}

const List<String> _legacyPaths = <String>[
  RoutePaths.legacyPlanningRoute,
  RoutePaths.legacyLogs,
  RoutePaths.legacyNotifications,
  RoutePaths.legacyProgression,
  RoutePaths.legacySi,
  RoutePaths.legacyTasks,
  RoutePaths.legacyProfile,
];

const List<String> _allLocations = <String>[
  RoutePaths.shell,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.home,
  RoutePaths.nexus,
  RoutePaths.plan,
  RoutePaths.creator,
  RoutePaths.legacyInsights,
  RoutePaths.settings,
  RoutePaths.notifications,
  RoutePaths.logs,
  RoutePaths.tasks,
  RoutePaths.profile,
  RoutePaths.progression,
  RoutePaths.si,
  RoutePaths.advisor,
  RoutePaths.paywall,
  RoutePaths.privacy,
  RoutePaths.deleteAccount,
  RoutePaths.terms,
  RoutePaths.support,
  RoutePaths.about,
  ..._legacyPaths,
  '/unknown-route',
  '/xyz123',
];

void main() {
  group('computeAppRedirect fuzz grid', () {
    for (final bool isAuthenticated in <bool>[false, true]) {
      for (final bool onboardingComplete in <bool>[false, true]) {
        for (final bool mockLoginEnabled in <bool>[false, true]) {
          for (final String location in _allLocations) {
            test('stabilizes within redirectLimit: '
                'auth=$isAuthenticated onboarding=$onboardingComplete '
                'mock=$mockLoginEnabled @ $location', () {
              final String? stable = _followToStableLocation(
                isAuthenticated: isAuthenticated,
                onboardingComplete: onboardingComplete,
                mockLoginEnabled: mockLoginEnabled,
                location: location,
              );
              expect(
                stable,
                isNotNull,
                reason:
                    'computeAppRedirect did not stabilize within 5 hops '
                    'from $location (auth=$isAuthenticated, '
                    'onboarding=$onboardingComplete, mock=$mockLoginEnabled) '
                    '— this combination would throw '
                    'TooManyRedirectsException in the real router.',
              );
            });
          }
        }
      }
    }
  });

  group('legacy routes', () {
    for (final String path in _legacyPaths) {
      test('$path: onboarding incomplete redirects to onboarding first', () {
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            onboardingComplete: false,
            mockLoginEnabled: false,
            location: path,
          ),
          RoutePaths.onboarding,
        );
      });

      test('$path: onboarded but signed out redirects to login first', () {
        expect(
          computeAppRedirect(
            isAuthenticated: false,
            onboardingComplete: true,
            mockLoginEnabled: false,
            location: path,
          ),
          RoutePaths.login,
        );
      });

      test('$path: onboarded and authenticated defers to the route-level '
          'redirect (top-level returns null)', () {
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            onboardingComplete: true,
            mockLoginEnabled: false,
            location: path,
          ),
          isNull,
        );
      });
    }
  });

  group('known top-level behaviors preserved', () {
    test('shell redirects home once authenticated', () {
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          onboardingComplete: true,
          mockLoginEnabled: false,
          location: RoutePaths.shell,
        ),
        RoutePaths.nexus,
      );
    });

    test('mock login bypasses the onboarding gate at /login', () {
      expect(
        computeAppRedirect(
          isAuthenticated: false,
          onboardingComplete: false,
          mockLoginEnabled: true,
          location: RoutePaths.login,
        ),
        isNull,
      );
    });

    test('login redirects home once authenticated', () {
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          onboardingComplete: true,
          mockLoginEnabled: false,
          location: RoutePaths.login,
        ),
        RoutePaths.nexus,
      );
    });
  });
}
