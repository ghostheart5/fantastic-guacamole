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
  required bool welcomeComplete,
  required bool onboardingComplete,
  required String location,
}) {
  String current = location;
  for (int i = 0; i < 5; i++) {
    final String? next = computeAppRedirect(
      isAuthenticated: isAuthenticated,
      welcomeComplete: welcomeComplete,
      onboardingComplete: onboardingComplete,
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
      for (final bool welcomeComplete in <bool>[false, true]) {
        for (final bool onboardingComplete in <bool>[false, true]) {
          for (final String location in _allLocations) {
            test('stabilizes within redirectLimit: '
                'auth=$isAuthenticated welcome=$welcomeComplete '
                'onboarding=$onboardingComplete @ $location', () {
              final String? stable = _followToStableLocation(
                isAuthenticated: isAuthenticated,
                welcomeComplete: welcomeComplete,
                onboardingComplete: onboardingComplete,
                location: location,
              );
              expect(
                stable,
                isNotNull,
                reason:
                    'computeAppRedirect did not stabilize within 5 hops '
                    'from $location (auth=$isAuthenticated, '
                    'welcome=$welcomeComplete, '
                    'onboarding=$onboardingComplete) '
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
      test('$path: welcome incomplete redirects to welcome first', () {
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            welcomeComplete: false,
            onboardingComplete: false,
            location: path,
          ),
          RoutePaths.onboarding,
        );
      });

      test('$path: welcome complete but signed out redirects to login', () {
        expect(
          computeAppRedirect(
            isAuthenticated: false,
            welcomeComplete: true,
            onboardingComplete: true,
            location: path,
          ),
          RoutePaths.login,
        );
      });

      test('$path: authenticated profile setup redirects to onboarding', () {
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            welcomeComplete: true,
            onboardingComplete: false,
            location: path,
          ),
          RoutePaths.onboarding,
        );
      });

      test('$path: onboarded and authenticated defers to the route-level '
          'redirect (top-level returns null)', () {
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
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
          welcomeComplete: true,
          onboardingComplete: true,
          location: RoutePaths.shell,
        ),
        RoutePaths.nexus,
      );
    });

    test('login cannot bypass the welcome gate', () {
      expect(
        computeAppRedirect(
          isAuthenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
          location: RoutePaths.login,
        ),
        RoutePaths.onboarding,
      );
    });

    test('successful login continues to name setup', () {
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: false,
          location: RoutePaths.login,
        ),
        RoutePaths.onboarding,
      );
    });

    test('login redirects home once authenticated', () {
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          location: RoutePaths.login,
        ),
        RoutePaths.nexus,
      );
    });
  });
}
