import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profile integration flow', () {
    test('profile route stays under advanced settings namespace', () {
      expect(RoutePaths.profile, startsWith(RoutePaths.advancedRoot));
      expect(RoutePaths.profile, contains('profile'));
    });

    test('profile app view transition is available', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appFlowProvider.notifier).toProfile();
      expect(container.read(appFlowProvider), AppView.profile);
    });
  });
}
