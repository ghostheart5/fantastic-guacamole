import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeSurfaceProvider', () {
    test('maps exported route surface to RoutePaths constants', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RouteSurface surface = container.read(routeSurfaceProvider);

      expect(surface.onboarding, RoutePaths.onboarding);
      expect(surface.login, RoutePaths.login);
      expect(surface.settings, RoutePaths.settings);
      expect(surface.paywall, RoutePaths.paywall);
      expect(surface.privacy, RoutePaths.privacy);
      expect(surface.deleteAccount, RoutePaths.deleteAccount);
      expect(surface.terms, RoutePaths.terms);
      expect(surface.support, RoutePaths.support);
      expect(surface.advisor, RoutePaths.advisor);
      expect(surface.notifications, RoutePaths.notifications);
      expect(
        surface.notificationPermissionRecovery,
        RoutePaths.notificationPermissionRecovery,
      );
    });

    test('advanced settings paths remain under the settings namespace', () {
      expect(RoutePaths.advancedRoot.startsWith('/settings'), isTrue);
      expect(RoutePaths.notifications.startsWith('/settings'), isTrue);
      expect(
        RoutePaths.notificationPermissionRecovery.startsWith('/settings'),
        isTrue,
      );
    });
  });
}
