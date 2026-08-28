import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('external deep-link destination coverage', () {
    test('maps every supported destination to its canonical route', () {
      for (final String path in <String>['/app', '/app/']) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: path,
        );
        expect(resolveExternalDeepLinkLocation(source), RoutePaths.nexus);
      }

      for (final AppRouteDefinition route in AppRouteRegistry.canonical.where(
        (AppRouteDefinition route) => route.externalSlug != null,
      )) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: '/app/${route.externalSlug}',
        );

        expect(
          resolveExternalDeepLinkLocation(source),
          route.path,
          reason: route.externalSlug,
        );
      }
    });

    test('retains approved compatibility aliases', () {
      for (final AppRouteCompatibility alias
          in AppRouteRegistry.compatibility.where(
            (AppRouteCompatibility alias) => alias.externalSlug != null,
          )) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: '/app/${alias.externalSlug}',
        );

        expect(
          resolveExternalDeepLinkLocation(source),
          alias.targetPath,
          reason: alias.externalSlug,
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
