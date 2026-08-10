import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-1 core-loop transition chain contract', () {
    test(
      'create-to-timeline action markers remain wired across task mutations',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);

        expect(text.contains("if (actionSource == 'timeline') {"), isTrue);
        expect(
          SourceTestUtils.countMatches(
            text,
            RegExp(r"unawaited\(_markTimelineFirstActionCompleted\(\)\);"),
          ),
          greaterThanOrEqualTo(3),
        );
        expect(text.contains("'task_created'"), isTrue);
        expect(text.contains("'task_completed'"), isTrue);
        expect(text.contains("'task_skipped'"), isTrue);
        expect(text.contains("String delayReason = 'reschedule'"), isTrue);
        expect(text.contains('CompletionEventType.rescheduled'), isTrue);
      },
    );

    test(
      'completion event write path remains persistence-first then invalidation',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);

        final int persistIndex = text.indexOf(
          'await _ref.read(completionEventRepositoryProvider).addEvent(event);',
        );
        final int invalidateIndex = text.indexOf(
          '_ref.invalidate(completionEventsProvider);',
        );

        expect(persistIndex, greaterThanOrEqualTo(0));
        expect(invalidateIndex, greaterThan(persistIndex));
      },
    );

    test(
      'event-bus fan-out continues to invalidate completion events for task and goal lifecycles',
      () {
        final File eventBusFile = File(
          'lib/state/providers/event_bus_provider.dart',
        );
        expect(eventBusFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(eventBusFile);

        final int taskListenerIndex = text.indexOf(
          'bus.on<TaskLifecycleEvent>().listen',
        );
        final int goalListenerIndex = text.indexOf(
          'bus.on<GoalLifecycleEvent>().listen',
        );
        expect(taskListenerIndex, greaterThanOrEqualTo(0));
        expect(goalListenerIndex, greaterThan(taskListenerIndex));

        expect(
          SourceTestUtils.countMatches(
            text,
            RegExp(r'ref\.invalidate\(completionEventsProvider\);'),
          ),
          greaterThanOrEqualTo(2),
        );
      },
    );
  });
}
