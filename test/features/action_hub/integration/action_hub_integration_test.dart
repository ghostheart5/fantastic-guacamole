import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('action_hub integration flow', () {
    test('app flow transitions from nexus to smart coach and back', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFlowProvider), AppView.nexus);
      container.read(appFlowProvider.notifier).toSmartCoach();
      expect(container.read(appFlowProvider), AppView.smartCoach);
      container.read(appFlowProvider.notifier).toCoach();
      expect(container.read(appFlowProvider), AppView.coach);
      container.read(appFlowProvider.notifier).toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);
    });
  });
}
