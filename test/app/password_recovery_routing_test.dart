import 'dart:async';

import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/auth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'verified recovery takes precedence over all account/onboarding states',
    () {
      for (final authenticated in [false, true]) {
        for (final welcome in [false, true]) {
          for (final onboarding in [false, true]) {
            expect(
              computeAppRedirect(
                isAuthenticated: authenticated,
                welcomeComplete: welcome,
                onboardingComplete: onboarding,
                location: RoutePaths.nexus,
                passwordRecoveryPending: true,
              ),
              '${RoutePaths.login}?mode=recovery',
            );
            expect(
              computeAppRedirect(
                isAuthenticated: authenticated,
                welcomeComplete: welcome,
                onboardingComplete: onboarding,
                location: RoutePaths.login,
                passwordRecoveryPending: true,
              ),
              isNull,
            );
          }
        }
      }
    },
  );

  test('raw recovery mode cannot retain an ordinary signed-in session', () {
    expect(
      computeAppRedirect(
        isAuthenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
        location: RoutePaths.login,
        deepLinkMode: DeepLinkMode.recovery,
      ),
      RoutePaths.nexus,
    );
  });

  test('exact native callback is sanitized without forwarding credentials', () {
    final uri = Uri.parse(
      'chronospark://auth-callback#type=recovery&access_token=secret&refresh_token=secret',
    );
    expect(isTrustedAuthCallback(uri), isTrue);
    expect(
      resolveExternalDeepLinkLocation(uri),
      '${RoutePaths.login}?mode=recovery',
    );
    for (final raw in [
      'chronospark://auth-callback/extra?type=recovery',
      'chronospark://attacker/app/auth/callback?type=recovery',
      'chronospark://user@auth-callback?type=recovery',
      'chronospark://auth-callback:123?type=recovery',
    ]) {
      expect(isTrustedAuthCallback(Uri.parse(raw)), isFalse, reason: raw);
      expect(
        resolveExternalDeepLinkLocation(Uri.parse(raw)),
        isEmpty,
        reason: raw,
      );
    }
  });

  test(
    'cold-start and warm native callbacks reach the deep-link service',
    () async {
      final events = StreamController<Uri>.broadcast();
      final initial = Uri.parse('chronospark://auth-callback?code=initial');
      final service = DeepLinkService.forTesting(
        initialLinkLoader: () async => initial,
        uriLinkStream: events.stream,
      );
      addTearDown(() async {
        await service.dispose();
        await events.close();
      });
      await service.initializeEarly();
      expect(service.latestUri, initial);
      final warm = service.links.first;
      events.add(Uri.parse('chronospark://attacker?code=rejected'));
      final accepted = Uri.parse('chronospark://auth-callback?code=warm');
      events.add(accepted);
      expect(await warm, accepted);
    },
  );
}
