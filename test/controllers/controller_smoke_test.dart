import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Controller smoke tests', () {
    test('AppFlowController initializes safely', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(appFlowProvider.notifier),
        returnsNormally,
      );

      expect(
        container.read(appFlowProvider),
        AppView.nexus,
      );
    });

    test('AppFlowController transitions do not throw', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(appFlowProvider.notifier);

      expect(() => controller.toGoals(), returnsNormally);
      expect(() => controller.toTimeline(), returnsNormally);
      expect(() => controller.toTasks(), returnsNormally);
      expect(() => controller.toMemories(), returnsNormally);
      expect(() => controller.toMilestones(), returnsNormally);
      expect(() => controller.toFlowmap(), returnsNormally);
      expect(() => controller.toSoulMap(), returnsNormally);
      expect(() => controller.toSettings(), returnsNormally);
      expect(() => controller.toNexus(), returnsNormally);
    });

    test('LearningController initializes safely', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(learningProvider.notifier),
        returnsNormally,
      );

      expect(
        () => container.read(learningProvider),
        returnsNormally,
      );
    });

    test('Controllers survive repeated access', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 25; i++) {
        container.read(appFlowProvider);
        container.read(appFlowProvider.notifier);
        container.read(learningProvider);
        container.read(learningProvider.notifier);
      }
    });
  });
}
