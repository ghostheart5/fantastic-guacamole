import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Provider smoke tests', () {
    test('core providers initialize without throwing', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(appFlowProvider),
        returnsNormally,
      );

      expect(
        () => container.read(appFlowProvider.notifier),
        returnsNormally,
      );

      expect(
        () => container.read(appAccessProvider),
        returnsNormally,
      );

      expect(
        () => container.read(intelligenceStateProvider),
        returnsNormally,
      );
    });

    test('app flow provider starts at nexus', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appFlowProvider),
        AppView.nexus,
      );
    });

    test('app flow notifier can transition safely', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appFlowProvider.notifier);

      controller.toGoals();
      expect(container.read(appFlowProvider), AppView.goals);

      controller.toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);

      controller.toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);
    });

    test('providers can be read repeatedly', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 25; i++) {
        expect(() => container.read(appFlowProvider), returnsNormally);
        expect(() => container.read(appAccessProvider), returnsNormally);
        expect(
          () => container.read(intelligenceStateProvider),
          returnsNormally,
        );
      }
    });
  });
}
