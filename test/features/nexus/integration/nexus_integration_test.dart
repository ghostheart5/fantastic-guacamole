import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('nexus integration flow', () {
    test('nexus is default view and can be restored after transitions', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFlowProvider), AppView.nexus);
      container.read(appFlowProvider.notifier).toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);
      container.read(appFlowProvider.notifier).toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);
    });
  });
}

