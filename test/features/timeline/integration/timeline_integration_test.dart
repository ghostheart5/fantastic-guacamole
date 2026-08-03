import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('timeline integration flow', () {
    test('timeline route remains under advanced settings namespace', () {
      expect(RoutePaths.timeline, startsWith(RoutePaths.advancedRoot));
      expect(RoutePaths.timeline, contains('logs'));
    });

    test('timeline app view transition is available', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appFlowProvider.notifier).toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);
    });
  });
}
