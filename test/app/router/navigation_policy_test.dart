import 'dart:io';

import 'package:fantastic_guacamole/app/router/navigation_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth callback startup routing', () {
    test('allows a cold-start custom-scheme recovery callback', () {
      final Uri callback = Uri.parse(
        'chronospark://auth-callback?type=recovery',
      );
      final String location = resolveDeepLinkLocation(callback);

      expect(location, '${RoutePaths.login}?mode=recovery');
      expect(
        resolveStartupRouteGate(
          location: RoutePaths.login,
          uri: Uri.parse(location),
          onboardingStatus: OnboardingStatus.unknown,
        ),
        StartupRouteGate.allow,
      );
    });

    test('allows a cold-start HTTPS verification callback', () {
      final Uri callback = Uri.parse(
        'https://chronospark.app/app/auth/callback#type=invite',
      );
      final String location = resolveDeepLinkLocation(callback);

      expect(location, '${RoutePaths.login}?mode=verify-email');
      expect(
        resolveStartupRouteGate(
          location: RoutePaths.login,
          uri: Uri.parse(location),
          onboardingStatus: OnboardingStatus.unknown,
        ),
        StartupRouteGate.allow,
      );
    });

    test('allows a warm-start auth callback', () {
      expect(
        resolveStartupRouteGate(
          location: RoutePaths.login,
          uri: Uri.parse('${RoutePaths.login}?mode=auth-callback'),
          onboardingStatus: OnboardingStatus.complete,
        ),
        StartupRouteGate.allow,
      );
    });

    test('holds normal unresolved startup routes on bootstrap', () {
      expect(
        resolveStartupRouteGate(
          location: RoutePaths.home,
          uri: Uri.parse(RoutePaths.home),
          onboardingStatus: OnboardingStatus.unknown,
        ),
        StartupRouteGate.redirectToBootstrap,
      );
      expect(
        resolveStartupRouteGate(
          location: RoutePaths.bootstrap,
          uri: Uri.parse(RoutePaths.bootstrap),
          onboardingStatus: OnboardingStatus.unknown,
        ),
        StartupRouteGate.allow,
      );
    });
  });

  group('deep-link path allowlist', () {
    test('maps every supported app-link path to its declared route', () {
      final Map<String, String> routes = <String, String>{
        '/app': RoutePaths.home,
        '/app/home': RoutePaths.home,
        '/app/plan': RoutePaths.plan,
        '/app/creator': RoutePaths.creator,
        '/app/insights': RoutePaths.insights,
        '/app/settings': RoutePaths.settings,
        '/app/notifications': RoutePaths.notifications,
        '/app/timeline': RoutePaths.timeline,
        '/app/tasks': RoutePaths.tasks,
        '/app/profile': RoutePaths.profile,
        '/app/progression': RoutePaths.progression,
        '/app/si-console': RoutePaths.si,
        '/app/advisor': RoutePaths.advisor,
        '/app/paywall': RoutePaths.paywall,
        '/app/paywall/compare': RoutePaths.planComparison,
        '/app/paywall/credits': RoutePaths.creditStore,
        '/app/paywall/credits/history': RoutePaths.creditHistory,
        '/app/paywall/manage': RoutePaths.subscriptionManagement,
        '/app/privacy': RoutePaths.privacy,
        '/app/delete-account': RoutePaths.deleteAccount,
        '/app/terms': RoutePaths.terms,
        '/app/support': RoutePaths.support,
        '/app/about': RoutePaths.about,
      };

      for (final MapEntry<String, String> entry in routes.entries) {
        expect(
          resolveDeepLinkLocation(
            Uri.parse('https://chronospark.app${entry.key}'),
          ),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test(
      'rejects malformed and unknown app-link paths to the controlled route',
      () {
        expect(
          resolveDeepLinkLocation(Uri.parse('https://chronospark.app/app//')),
          RoutePaths.unsupportedLink,
        );
        expect(
          resolveDeepLinkLocation(
            Uri.parse('https://chronospark.app/app/profile-preview'),
          ),
          RoutePaths.unsupportedLink,
        );
      },
    );
  });

  group('route-level access', () {
    test(
      'registers the destructive route only outside release or with admin access',
      () {
        expect(
          shouldRegisterCompletionEventsRoute(
            isReleaseMode: true,
            hasAdminAccess: false,
          ),
          isFalse,
        );
        expect(
          shouldRegisterCompletionEventsRoute(
            isReleaseMode: true,
            hasAdminAccess: true,
          ),
          isTrue,
        );
        expect(
          shouldRegisterCompletionEventsRoute(
            isReleaseMode: false,
            hasAdminAccess: false,
          ),
          isTrue,
        );
      },
    );
  });

  group('notification destination allowlist', () {
    test('maps valid notification destinations to known routes', () {
      expect(
        resolveNotificationPayloadLocation('{"destination":"task"}'),
        RoutePaths.creator,
      );
      expect(
        resolveNotificationPayloadLocation('{"destination":"goal"}'),
        RoutePaths.creator,
      );
      expect(
        resolveNotificationPayloadLocation('{"destination":"timeline"}'),
        RoutePaths.timeline,
      );
      expect(
        resolveNotificationPayloadLocation('{"destination":"siConsole"}'),
        RoutePaths.si,
      );
      expect(
        resolveNotificationPayloadLocation('{"destination":"home"}'),
        RoutePaths.home,
      );
    });

    test('rejects arbitrary, malformed, empty, and unknown payload routes', () {
      expect(
        resolveNotificationPayloadLocation('{"route":"/settings"}'),
        RoutePaths.notifications,
      );
      expect(
        resolveNotificationPayloadLocation('{"route":""}'),
        RoutePaths.notifications,
      );
      expect(
        resolveNotificationPayloadLocation('{"route":"/not-registered"}'),
        RoutePaths.notifications,
      );
      expect(resolveNotificationPayloadLocation('{'), RoutePaths.notifications);
      expect(
        resolveNotificationPayloadLocation('{"destination":""}'),
        RoutePaths.notifications,
      );
      expect(
        resolveNotificationPayloadLocation('{"destination":"settings"}'),
        RoutePaths.notifications,
      );
    });
  });

  test(
    'Apple Universal Links are disabled and contain no placeholder configuration',
    () {
      final File entitlements = File('ios/Runner/Runner.entitlements');
      final File association = File(
        'web/.well-known/apple-app-site-association',
      );
      final String iosConfig = entitlements.readAsStringSync();
      final Iterable<File> appLinkConfigFiles =
          <File>[
            ...Directory('ios').listSync(recursive: true).whereType<File>(),
            ...Directory('web').listSync(recursive: true).whereType<File>(),
          ].where((File file) {
            final String path = file.path.toLowerCase();
            return path.contains('entitlement') ||
                path.contains('apple-app-site-association') ||
                path.contains('assetlinks');
          });

      expect(association.existsSync(), isFalse);
      expect(
        iosConfig.contains('com.apple.developer.associated-domains'),
        isFalse,
      );
      for (final File file in appLinkConfigFiles) {
        expect(
          file.readAsStringSync().contains('REPLACE_WITH_TEAM_ID'),
          isFalse,
          reason: file.path,
        );
      }
    },
  );

  test('About and plan comparison have intentional in-app entry points', () {
    final String settings = File(
      'lib/features/settings/ui/settings_screen.dart',
    ).readAsStringSync();
    final String paywall = File(
      'lib/features/monetization/presentation/screens/paywall_screen.dart',
    ).readAsStringSync();

    expect(settings.contains('RoutePaths.about'), isTrue);
    expect(paywall.contains('RoutePaths.planComparison'), isTrue);
  });
}
