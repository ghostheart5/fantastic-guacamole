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
            RegExp(r'await _markTimelineFirstActionCompleted\(\);'),
          ),
          greaterThanOrEqualTo(3),
        );
        expect(text.contains("'task_created'"), isTrue);
        expect(text.contains("'task_completed'"), isTrue);
        expect(text.contains("'task_skipped_event_emitted'"), isTrue);
        expect(text.contains("String delayReason = 'reschedule'"), isTrue);
        final String completionAdapter = SourceTestUtils.readText(
          File('lib/data/adapters/task_occurrence_completion_adapter.dart'),
        );
        expect(
          completionAdapter.contains('CompletionEventType.rescheduled'),
          isTrue,
        );
      },
    );

    test(
      'completion event write path remains persistence-first then invalidation',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        final File coordinatorFile = File(
          'lib/state/services/task_occurrence_projection_coordinator.dart',
        );
        final File completionAdapterFile = File(
          'lib/data/adapters/task_occurrence_completion_adapter.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);
        expect(coordinatorFile.existsSync(), isTrue);
        expect(completionAdapterFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);
        final String coordinatorText = SourceTestUtils.readText(
          coordinatorFile,
        );
        final String completionAdapterText = SourceTestUtils.readText(
          completionAdapterFile,
        );

        final int projectIndex = text.indexOf('() => _projections.project(');
        final int invalidateIndex = text.indexOf(
          '_invalidateOccurrenceProjections();',
        );

        expect(projectIndex, greaterThanOrEqualTo(0));
        expect(invalidateIndex, greaterThan(projectIndex));
        expect(
          coordinatorText.contains('() => completion.recordTransition('),
          isTrue,
        );
        expect(
          completionAdapterText.contains('await _completionEvents.addEvent('),
          isTrue,
        );
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
