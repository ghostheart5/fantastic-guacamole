import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation integration flow', () {
    test('appFlowProvider transitions across primary surfaces', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFlowProvider), AppView.nexus);

      container.read(appFlowProvider.notifier).toCreator();
      expect(container.read(appFlowProvider), AppView.creator);

      container.read(appFlowProvider.notifier).toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);

      container.read(appFlowProvider.notifier).toSettings();
      expect(container.read(appFlowProvider), AppView.settings);
    });

    test('route surface exposes stable login/settings/notifications paths', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RouteSurface routes = container.read(routeSurfaceProvider);
      expect(routes.login, startsWith('/'));
      expect(routes.settings, startsWith('/'));
      expect(routes.notifications, startsWith('/settings'));
      expect(routes.notificationPermissionRecovery, contains('/recovery'));
    });

    test('appViewFromName resolves valid names and rejects invalid values', () {
      expect(appViewFromName('nexus'), AppView.nexus);
      expect(appViewFromName('smartCoach'), AppView.smartCoach);
      expect(appViewFromName('unknown_view'), isNull);
      expect(appViewFromName('  '), isNull);
    });
  });
}
