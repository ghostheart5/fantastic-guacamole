import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('external deep-link privacy', () {
    test('strips unapproved query parameters and fragments', () {
      final Uri source = Uri.parse(
        'https://chronospark.app/app/creator'
        '?access_token=query-secret&day=7&returnTo=%2Fsettings'
        '#refresh_token=fragment-secret&block=7',
      );

      final String location = resolveExternalDeepLinkLocation(source);
      final Uri resolved = Uri.parse(location);

      expect(location, RoutePaths.creator);
      expect(resolved.queryParameters, isEmpty);
      expect(resolved.fragment, isEmpty);
      expect(location, isNot(contains('secret')));
    });

    test('allows only an exact single saved-tab flag on Nexus links', () {
      final Uri source = Uri.parse(
        'https://chronospark.app/app/nexus'
        '?restoreSavedTab=true&access_token=query-secret'
        '#refresh_token=fragment-secret',
      );

      final Uri resolved = Uri.parse(resolveExternalDeepLinkLocation(source));

      expect(resolved.path, RoutePaths.nexus);
      expect(resolved.queryParameters, <String, String>{
        restoreSavedTabQueryParameter: 'true',
      });
      expect(resolved.fragment, isEmpty);
    });

    test('rejects duplicate or non-exact saved-tab flags', () {
      for (final String query in <String>[
        'restoreSavedTab=true&restoreSavedTab=true',
        'restoreSavedTab=TRUE',
        'restoreSavedTab=1',
      ]) {
        final Uri source = Uri.parse(
          'https://chronospark.app/app/nexus?$query',
        );

        expect(resolveExternalDeepLinkLocation(source), RoutePaths.nexus);
      }
    });

    test('rejects saved-tab flags duplicated or supplied in fragments', () {
      for (final Uri source in <Uri>[
        Uri.parse(
          'https://chronospark.app/app/nexus'
          '?restoreSavedTab=true#restoreSavedTab=true',
        ),
        Uri.parse(
          'https://chronospark.app/app/nexus'
          '?restoreSavedTab=true#restoreSavedTab=false',
        ),
        Uri.parse('https://chronospark.app/app/nexus#restoreSavedTab=true'),
      ]) {
        expect(resolveExternalDeepLinkLocation(source), RoutePaths.nexus);
      }
    });

    test('auth callback forwards only derived mode and sanitized returnTo', () {
      final Uri source = Uri.parse(
        'https://chronospark.app/app/auth/callback'
        '?returnTo=%2Fnexus%3FrestoreSavedTab%3Dtrue%26token%3Dnested-secret%23leak'
        '&access_token=query-secret'
        '#type=recovery&access_token=fragment-secret&refresh_token=refresh-secret',
      );

      final String location = resolveExternalDeepLinkLocation(source);
      final Uri resolved = Uri.parse(location);

      expect(resolved.path, RoutePaths.login);
      expect(resolved.queryParameters['mode'], 'recovery');
      expect(
        resolved.queryParameters[RouteAccessPolicy.returnToQueryParameter],
        '/nexus?restoreSavedTab=true',
      );
      expect(resolved.queryParameters.length, 2);
      expect(resolved.fragment, isEmpty);
      expect(location, isNot(contains('secret')));
      expect(location, isNot(contains('token')));
    });

    test('ambiguous auth parameters fail closed', () {
      final Uri source = Uri.parse(
        'https://chronospark.app/app/auth/callback'
        '?type=signup&returnTo=%2Fcreator'
        '#type=recovery&returnTo=%2Fsettings',
      );

      final Uri resolved = Uri.parse(resolveExternalDeepLinkLocation(source));

      expect(resolved.queryParameters, <String, String>{
        'mode': 'auth-callback',
      });
    });

    test('auth callback rejects unapproved internal return destinations', () {
      for (final String returnTo in <String>[
        RoutePaths.tasks,
        RoutePaths.advisor,
        RoutePaths.login,
        RoutePaths.onboarding,
        RoutePaths.legacyLogs,
        RoutePaths.legacyTasks,
        RoutePaths.legacyInsights,
      ]) {
        final Uri source = Uri(
          scheme: 'https',
          host: 'chronospark.app',
          path: '/app/auth/callback',
          queryParameters: <String, String>{
            'type': 'signup',
            RouteAccessPolicy.returnToQueryParameter: returnTo,
          },
        );

        expect(
          Uri.parse(resolveExternalDeepLinkLocation(source)).queryParameters,
          <String, String>{'mode': 'verify-email'},
          reason: returnTo,
        );
      }
    });

    test('percent-like auth fragments fail closed without throwing', () {
      final Uri source = Uri(
        scheme: 'https',
        host: 'chronospark.app',
        path: '/app/auth/callback',
        fragment: 'type=%',
      );

      expect(() => resolveExternalDeepLinkLocation(source), returnsNormally);
      expect(
        Uri.parse(
          resolveExternalDeepLinkLocation(source),
        ).queryParameters['mode'],
        'auth-callback',
      );
    });

    test('unsupported destinations fail closed without retaining input', () {
      final Uri source = Uri.parse(
        'https://chronospark.app/app/not-supported'
        '?restoreSavedTab=true&token=query-secret#fragment-secret',
      );

      expect(resolveExternalDeepLinkLocation(source), isEmpty);
    });
  });
}
