import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Workflow chain contract', () {
    test(
      'creator to timeline to completion to progression chain stays wired',
      () {
        final File taskProvider = File(
          'lib/state/providers/task_provider.dart',
        );
        final File timelineProvider = File(
          'lib/state/providers/timeline_provider.dart',
        );
        final File progressionProvider = File(
          'lib/state/providers/progression_provider.dart',
        );
        final File appRouter = File('lib/app/router/app_router.dart');
        final File completionUsecaseTest = File(
          'test/unit/complete_task_usecase_test.dart',
        );

        expect(taskProvider.existsSync(), isTrue);
        expect(timelineProvider.existsSync(), isTrue);
        expect(progressionProvider.existsSync(), isTrue);
        expect(appRouter.existsSync(), isTrue);
        expect(completionUsecaseTest.existsSync(), isTrue);

        final String taskText = SourceTestUtils.readText(taskProvider);
        final String timelineText = SourceTestUtils.readText(timelineProvider);
        final String progressionText = SourceTestUtils.readText(
          progressionProvider,
        );
        final String routerText = SourceTestUtils.readText(appRouter);

        expect(taskText.contains('createTaskUseCaseProvider'), isTrue);
        expect(taskText.contains('timelineActionsProvider'), isTrue);
        expect(taskText.contains('connectTask(normalized)'), isTrue);
        expect(taskText.contains('taskOccurrenceCoordinatorProvider'), isTrue);
        expect(taskText.contains('_occurrences.complete('), isTrue);
        expect(taskText.contains('if (actionSource == \'timeline\')'), isTrue);
        expect(taskText.contains('_markTimelineFirstActionCompleted'), isTrue);
        expect(taskText.contains("'task_created'"), isTrue);
        expect(taskText.contains("'task_completed'"), isTrue);

        expect(timelineText.contains('final timelineProvider ='), isTrue);
        expect(
          timelineText.contains('timelineCompletedEventsProvider'),
          isTrue,
        );
        expect(timelineText.contains('timelineOverdueProvider'), isTrue);

        expect(progressionText.contains('final progressionProvider ='), isTrue);
        expect(
          progressionText.contains('service.fromProfile(profile)'),
          isTrue,
        );

        expect(
          routerText.contains('creatorFirstItemCreatedGuardProvider'),
          isTrue,
        );
        expect(
          routerText.contains('timelineFirstActionCompletedGuardProvider'),
          isTrue,
        );
      },
    );
  });
}
