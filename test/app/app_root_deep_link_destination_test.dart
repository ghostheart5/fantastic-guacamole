import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('external deep-link destination coverage', () {
    test('maps every supported destination to its canonical route', () {
      const Map<String, String> expectedLocations = <String, String>{
        '/app': RoutePaths.nexus,
        '/app/': RoutePaths.nexus,
        '/app/nexus': RoutePaths.nexus,
        '/app/smart-planner': RoutePaths.smartPlanner,
        '/app/creator': RoutePaths.creator,
        '/app/goals': RoutePaths.creatorGoals,
        '/app/settings': RoutePaths.settings,
        '/app/notifications': RoutePaths.notifications,
        '/app/profile': RoutePaths.profile,
        '/app/progression': RoutePaths.progression,
        '/app/si-console': RoutePaths.siConsole,
        '/app/timeline': RoutePaths.timeline,
        '/app/trajectory': RoutePaths.trajectoryEngine,
        '/app/paywall': RoutePaths.paywall,
        '/app/privacy': RoutePaths.privacy,
        '/app/delete-account': RoutePaths.deleteAccount,
        '/app/terms': RoutePaths.terms,
        '/app/support': RoutePaths.support,
        '/app/about': RoutePaths.about,
      };

      for (final MapEntry<String, String> entry in expectedLocations.entries) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: entry.key,
        );

        expect(
          resolveExternalDeepLinkLocation(source),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('retains approved compatibility aliases', () {
      const Map<String, String> expectedLocations = <String, String>{
        '/app/home': RoutePaths.nexus,
        '/app/plan': RoutePaths.timeline,
        '/app/temporal': RoutePaths.timeline,
        '/app/logs': RoutePaths.logs,
        '/app/si': RoutePaths.siConsole,
      };

      for (final MapEntry<String, String> entry in expectedLocations.entries) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: entry.key,
        );

        expect(
          resolveExternalDeepLinkLocation(source),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('rejects internal, legacy, and unknown destinations', () {
      for (final String path in <String>[
        '/app/tasks',
        '/app/advisor',
        '/app/insights',
        '/app/login',
        '/app/onboarding',
        '/app/creator/goals',
        '/app/settings/advanced/logs',
        '/app/not-supported',
      ]) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: path,
        );

        expect(resolveExternalDeepLinkLocation(source), isEmpty, reason: path);
      }
    });

    test('requires exact case-sensitive destination matches', () {
      for (final String path in <String>[
        '/app/Nexus',
        '/app/creator/goals/',
        '/app/trajectory/details',
      ]) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: path,
        );

        expect(resolveExternalDeepLinkLocation(source), isEmpty, reason: path);
      }
    });
  });
}
