import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('progression integration flow', () {
    test('progression route remains under advanced settings namespace', () {
      expect(RoutePaths.progression, startsWith(RoutePaths.advancedRoot));
      expect(RoutePaths.progression, contains('progression'));
    });

    test('progression app view transition is available', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appFlowProvider.notifier).toProgression();
      expect(container.read(appFlowProvider), AppView.progression);
    });
  });
}
