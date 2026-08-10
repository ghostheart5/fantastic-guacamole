import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ui integration flow', () {
    test('route surface exposes rooted user-facing paths', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RouteSurface surface = container.read(routeSurfaceProvider);
      expect(surface.onboarding, startsWith('/'));
      expect(surface.login, startsWith('/'));
      expect(surface.settings, startsWith('/'));
      expect(surface.notifications, startsWith('/settings'));
    });
  });
}
