import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('First-run funnel release contract', () {
    test('router enforces Creator then Timeline before full navigation', () {
      final File appRouter = File('lib/app/router/app_router.dart');
      expect(appRouter.existsSync(), isTrue);

      final String routerText = SourceTestUtils.readText(appRouter);

      expect(routerText.contains('creatorFirstItemCreatedGuardProvider'), isTrue);
      expect(routerText.contains('timelineFirstActionCompletedGuardProvider'), isTrue);
      expect(routerText.contains('if (!hasCreatedFirstItem)'), isTrue);
      expect(routerText.contains('if (!hasCompletedTimelineFirstAction)'), isTrue);
      expect(routerText.contains('location != RoutePaths.timeline'), isTrue);
      expect(routerText.contains('return RoutePaths.creator;'), isTrue);
      expect(routerText.contains('return RoutePaths.timeline;'), isTrue);
    });

    test('startup, onboarding reset, and timeline actions wire funnel state', () {
      final File bootstrap = File('lib/app/startup/app_bootstrap.dart');
      final File onboarding = File('lib/features/onboarding/ui/onboarding_screen.dart');
      final File tasks = File('lib/state/providers/task_provider.dart');

      expect(bootstrap.existsSync(), isTrue);
      expect(onboarding.existsSync(), isTrue);
      expect(tasks.existsSync(), isTrue);

      final String bootstrapText = SourceTestUtils.readText(bootstrap);
      final String onboardingText = SourceTestUtils.readText(onboarding);
      final String tasksText = SourceTestUtils.readText(tasks);

      expect(
        bootstrapText.contains('timelineFirstActionCompletedStorageKey'),
        isTrue,
      );
      expect(
        bootstrapText.contains('hasCompletedTimelineFirstAction'),
        isTrue,
      );
      expect(
        bootstrapText.contains('timelineFirstActionCompletedProvider.notifier'),
        isTrue,
      );

      expect(
        onboardingText.contains('timelineFirstActionCompletedStorageKey'),
        isTrue,
      );
      expect(
        onboardingText.contains('timelineFirstActionCompletedProvider.notifier'),
        isTrue,
      );

      expect(tasksText.contains("actionSource == 'timeline'"), isTrue);
      expect(tasksText.contains('_markTimelineFirstActionCompleted'), isTrue);
    });
  });
}
