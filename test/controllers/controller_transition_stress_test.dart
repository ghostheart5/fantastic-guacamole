import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Controller transition stress tests', () {
    test('AppFlowController survives repeated release-critical transitions', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AppFlowController controller = container.read(
        appFlowProvider.notifier,
      );

      final List<AppView> flow = <AppView>[
        AppView.nexus,
        AppView.smartCoach,
        AppView.goals,
        AppView.timeline,
        AppView.tasks,
        AppView.memories,
        AppView.milestones,
        AppView.flowmap,
        AppView.soulMap,
        AppView.settings,
        AppView.profile,
        AppView.logs,
        AppView.progression,
        AppView.plan,
        AppView.creator,
        AppView.insight,
        AppView.console,
      ];

      for (int cycle = 0; cycle < 50; cycle++) {
        for (final AppView view in flow) {
          controller.show(view);
          expect(
            container.read(appFlowProvider),
            view,
            reason: 'Cycle $cycle should transition safely to $view.',
          );
        }

        controller.toNexus();
        expect(
          container.read(appFlowProvider),
          AppView.nexus,
          reason: 'Cycle $cycle should safely return to Nexus.',
        );
      }
    });

    test('AppFlowController direct methods remain consistent with AppView states', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AppFlowController controller = container.read(
        appFlowProvider.notifier,
      );

      controller.toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);

      controller.toSmartCoach();
      expect(container.read(appFlowProvider), AppView.smartCoach);

      controller.toGoals();
      expect(container.read(appFlowProvider), AppView.goals);

      controller.toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);

      controller.toTasks();
      expect(container.read(appFlowProvider), AppView.tasks);

      controller.toMemories();
      expect(container.read(appFlowProvider), AppView.memories);

      controller.toMilestones();
      expect(container.read(appFlowProvider), AppView.milestones);

      controller.toFlowmap();
      expect(container.read(appFlowProvider), AppView.flowmap);

      controller.toSoulMap();
      expect(container.read(appFlowProvider), AppView.soulMap);

      controller.toSettings();
      expect(container.read(appFlowProvider), AppView.settings);

      controller.toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);
    });

    test('AppFlowController never produces null or invalid state under stress', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final AppFlowController controller = container.read(
        appFlowProvider.notifier,
      );

      for (int i = 0; i < 100; i++) {
        final AppView next = AppView.values[i % AppView.values.length];
        controller.show(next);

        final AppView current = container.read(appFlowProvider);

        expect(AppView.values.contains(current), isTrue);
      }
    });
  });
}
