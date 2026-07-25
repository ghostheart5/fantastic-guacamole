import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFlow navigation smoke test', () {
    test('all primary navigation transitions work', () {
      final container = ProviderContainer();

      expect(
        container.read(appFlowProvider),
        AppView.nexus,
      );

      container.read(appFlowProvider.notifier).toSmartCoach();
      expect(
        container.read(appFlowProvider),
        AppView.smartCoach,
      );

      container.read(appFlowProvider.notifier).toNexus();
      expect(
        container.read(appFlowProvider),
        AppView.nexus,
      );

      container.read(appFlowProvider.notifier).toGoals();
      expect(
        container.read(appFlowProvider),
        AppView.goals,
      );

      container.read(appFlowProvider.notifier).toTimeline();
      expect(
        container.read(appFlowProvider),
        AppView.timeline,
      );

      container.read(appFlowProvider.notifier).toTasks();
      expect(
        container.read(appFlowProvider),
        AppView.tasks,
      );

      container.read(appFlowProvider.notifier).toMemories();
      expect(
        container.read(appFlowProvider),
        AppView.memories,
      );

      container.read(appFlowProvider.notifier).toMilestones();
      expect(
        container.read(appFlowProvider),
        AppView.milestones,
      );

      container.read(appFlowProvider.notifier).toFlowmap();
      expect(
        container.read(appFlowProvider),
        AppView.flowmap,
      );

      container.read(appFlowProvider.notifier).toSoulMap();
      expect(
        container.read(appFlowProvider),
        AppView.soulMap,
      );

      container.read(appFlowProvider.notifier).toSettings();
      expect(
        container.read(appFlowProvider),
        AppView.settings,
      );

      container.dispose();
    });
  });
}