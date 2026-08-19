import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
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

String? _redirectUri({
  required bool isAuthenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
  required String rawUri,
  bool isDebugBuild = true,
}) {
  final Uri uri = Uri.parse(rawUri);
  return computeAppRedirect(
    isAuthenticated: isAuthenticated,
    welcomeComplete: welcomeComplete,
    onboardingComplete: onboardingComplete,
    location: uri.path,
    uri: uri,
    isDebugBuild: isDebugBuild,
  );
}

String? _returnToOf(String? redirect) {
  if (redirect == null) {
    return null;
  }
  return Uri.parse(
    redirect,
  ).queryParameters[RouteAccessPolicy.returnToQueryParameter];
}

String? _pathOf(String? redirect) {
  if (redirect == null) {
    return null;
  }
  return Uri.parse(redirect).path;
}

const List<String> _legacyPaths = <String>[
  RoutePaths.legacyLogs,
  RoutePaths.legacyNotifications,
  RoutePaths.legacyProgression,
  RoutePaths.legacySi,
  RoutePaths.legacyTasks,
  RoutePaths.legacyProfile,
  RoutePaths.legacyCoach,
  RoutePaths.legacySignals,
  RoutePaths.legacyInsights,
];

const List<String> _publicInformationPaths = <String>[
  RoutePaths.privacy,
  RoutePaths.terms,
  RoutePaths.support,
  RoutePaths.about,
];

const List<String> _protectedApplicationPaths = <String>[
  RoutePaths.shell,
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
  RoutePaths.timeline,
  RoutePaths.smartPlanner,
  RoutePaths.trajectoryEngine,
  ..._legacyPaths,
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
        final String? redirect = computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: false,
          onboardingComplete: false,
          location: path,
        );
        expect(_pathOf(redirect), RoutePaths.onboarding);
        expect(_returnToOf(redirect), path);
      });

      test('$path: welcome complete but signed out redirects to login', () {
        final String? redirect = computeAppRedirect(
          isAuthenticated: false,
          welcomeComplete: true,
          onboardingComplete: true,
          location: path,
        );
        expect(_pathOf(redirect), RoutePaths.login);
        expect(_returnToOf(redirect), path);
      });

      test('$path: authenticated profile setup redirects to onboarding', () {
        final String? redirect = computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: false,
          location: path,
        );
        expect(_pathOf(redirect), RoutePaths.onboarding);
        expect(_returnToOf(redirect), path);
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

  group('route access classes', () {
    test('classifies every declared route path', () {
      for (final String path in <String>[
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
        RoutePaths.smartPlanner,
        RoutePaths.siConsole,
        RoutePaths.timeline,
        RoutePaths.trajectoryEngine,
        RoutePaths.paywall,
        RoutePaths.privacy,
        RoutePaths.deleteAccount,
        RoutePaths.terms,
        RoutePaths.support,
        RoutePaths.about,
        ..._legacyPaths,
      ]) {
        expect(RouteAccessPolicy.classify(path).reason, isNotEmpty);
      }
    });

    test('public information pages are reachable while signed out', () {
      for (final String path in _publicInformationPaths) {
        expect(
          computeAppRedirect(
            isAuthenticated: false,
            welcomeComplete: false,
            onboardingComplete: false,
            location: path,
          ),
          isNull,
          reason: '$path should be public before sign-in.',
        );
      }
    });

    test('delete-account instructions are public information', () {
      expect(
        RouteAccessPolicy.classify(RoutePaths.deleteAccount).accessClass,
        RouteAccessClass.accountSensitiveInformation,
      );
      expect(
        computeAppRedirect(
          isAuthenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
          location: RoutePaths.deleteAccount,
        ),
        isNull,
      );
    });

    test('auth callback modes are not interrupted by welcome', () {
      for (final DeepLinkMode mode in DeepLinkMode.values) {
        expect(
          computeAppRedirect(
            isAuthenticated: false,
            welcomeComplete: false,
            onboardingComplete: false,
            location: RoutePaths.login,
            deepLinkMode: mode,
          ),
          isNull,
          reason: '$mode must reach AuthGate.',
        );
      }
    });

    test('normal login still respects welcome gate', () {
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

    test(
      'commercial route requires authentication but not completed setup',
      () {
        final String? redirect = computeAppRedirect(
          isAuthenticated: false,
          welcomeComplete: true,
          onboardingComplete: false,
          location: RoutePaths.paywall,
        );
        expect(_pathOf(redirect), RoutePaths.login);
        expect(_returnToOf(redirect), RoutePaths.paywall);
        expect(
          computeAppRedirect(
            isAuthenticated: true,
            welcomeComplete: true,
            onboardingComplete: false,
            location: RoutePaths.paywall,
          ),
          isNull,
        );
      },
    );

    test('protected app routes require authentication and completed setup', () {
      for (final String path in _protectedApplicationPaths) {
        final String? signedOutRedirect = computeAppRedirect(
          isAuthenticated: false,
          welcomeComplete: true,
          onboardingComplete: true,
          location: path,
        );
        expect(
          _pathOf(signedOutRedirect),
          RoutePaths.login,
          reason: '$path should require authentication.',
        );
        expect(_returnToOf(signedOutRedirect), path);

        final String? setupRedirect = computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: false,
          location: path,
        );
        expect(
          _pathOf(setupRedirect),
          RoutePaths.onboarding,
          reason: '$path should require completed setup.',
        );
        expect(_returnToOf(setupRedirect), path);
      }
    });

    test('advisor is internal and unavailable in release builds', () {
      expect(
        RouteAccessPolicy.classify(RoutePaths.advisor).accessClass,
        RouteAccessClass.privilegedInternal,
      );
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          location: RoutePaths.advisor,
          isDebugBuild: false,
        ),
        RoutePaths.settings,
      );
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          location: RoutePaths.advisor,
          isDebugBuild: true,
        ),
        RoutePaths.settings,
      );
      expect(
        computeAppRedirect(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          location: RoutePaths.advisor,
          isDebugBuild: true,
          hasInternalAdvisorAccess: true,
        ),
        isNull,
      );
    });
  });

  group('phase 2 callback and return destination handling', () {
    test('fresh install preserves recovery callback', () {
      expect(
        _redirectUri(
          isAuthenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
          rawUri: '/login?mode=recovery',
        ),
        isNull,
      );
    });

    test('fresh install preserves verification callback', () {
      expect(
        _redirectUri(
          isAuthenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
          rawUri: '/login?mode=verify-email',
        ),
        isNull,
      );
    });

    test('welcome-complete signed-out callbacks reach authentication', () {
      for (final String mode in <String>[
        'recovery',
        'verify-email',
        'auth-callback',
      ]) {
        expect(
          _redirectUri(
            isAuthenticated: false,
            welcomeComplete: true,
            onboardingComplete: false,
            rawUri: '/login?mode=$mode',
          ),
          isNull,
          reason: '$mode should reach AuthGate.',
        );
      }
    });

    test('callback received while already authenticated resumes safely', () {
      expect(
        _redirectUri(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          rawUri: '/login?mode=auth-callback',
        ),
        RoutePaths.nexus,
      );
    });

    test('authenticated callback restores validated return destination', () {
      expect(
        _redirectUri(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          rawUri: '/login?mode=auth-callback&returnTo=%2Fcreator',
        ),
        RoutePaths.creator,
      );
    });

    test('callback replay remains idempotent', () {
      final List<String?> redirects = List<String?>.generate(
        2,
        (_) => _redirectUri(
          isAuthenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
          rawUri: '/login?mode=recovery',
        ),
      );
      expect(redirects, everyElement(isNull));
    });

    test('protected deep link while signed out returns after login', () {
      final String? toLogin = _redirectUri(
        isAuthenticated: false,
        welcomeComplete: true,
        onboardingComplete: true,
        rawUri: '/creator',
      );
      expect(Uri.parse(toLogin!).path, RoutePaths.login);
      expect(_returnToOf(toLogin), RoutePaths.creator);

      final String? restored = _redirectUri(
        isAuthenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
        rawUri: toLogin,
      );
      expect(restored, RoutePaths.creator);
    });

    test('protected deep link survives welcome and onboarding gates', () {
      final String? toWelcome = _redirectUri(
        isAuthenticated: false,
        welcomeComplete: false,
        onboardingComplete: false,
        rawUri: '/trajectory',
      );
      expect(Uri.parse(toWelcome!).path, RoutePaths.onboarding);
      expect(_returnToOf(toWelcome), RoutePaths.trajectoryEngine);

      final String? toLogin = _redirectUri(
        isAuthenticated: false,
        welcomeComplete: true,
        onboardingComplete: false,
        rawUri: toWelcome,
      );
      expect(Uri.parse(toLogin!).path, RoutePaths.login);
      expect(_returnToOf(toLogin), RoutePaths.trajectoryEngine);

      final String? backToOnboarding = _redirectUri(
        isAuthenticated: true,
        welcomeComplete: true,
        onboardingComplete: false,
        rawUri: toLogin,
      );
      expect(Uri.parse(backToOnboarding!).path, RoutePaths.onboarding);
      expect(_returnToOf(backToOnboarding), RoutePaths.trajectoryEngine);

      final String? restored = _redirectUri(
        isAuthenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
        rawUri: backToOnboarding,
      );
      expect(restored, RoutePaths.trajectoryEngine);
    });

    test('invalid or hostile returnTo values are rejected', () {
      for (final String value in <String>[
        'https://evil.example/nexus',
        '//evil.example/nexus',
        'nexus',
        '/unknown-route',
        '/login',
        '/onboarding',
        '/settings/advanced/advisor',
        '/creator?returnTo=/timeline',
        '%zz',
      ]) {
        final String encoded = Uri.encodeComponent(value);
        expect(
          _redirectUri(
            isAuthenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
            rawUri: '/login?returnTo=$encoded',
          ),
          RoutePaths.nexus,
          reason: '$value must not be restored.',
        );
      }
    });

    test('query and fragment are preserved for allowed destinations', () {
      final String? toLogin = _redirectUri(
        isAuthenticated: false,
        welcomeComplete: true,
        onboardingComplete: true,
        rawUri: '/timeline?day=2026-08-19#block-7',
      );
      expect(Uri.parse(toLogin!).path, RoutePaths.login);
      expect(_returnToOf(toLogin), '/timeline?day=2026-08-19#block-7');

      expect(
        _redirectUri(
          isAuthenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
          rawUri: toLogin,
        ),
        '/timeline?day=2026-08-19#block-7',
      );
    });

    test('hostile returnTo on requested protected URL is stripped', () {
      final String? toLogin = _redirectUri(
        isAuthenticated: false,
        welcomeComplete: true,
        onboardingComplete: true,
        rawUri: '/creator?returnTo=https%3A%2F%2Fevil.example',
      );
      expect(Uri.parse(toLogin!).path, RoutePaths.login);
      expect(_returnToOf(toLogin), RoutePaths.creator);
    });
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
