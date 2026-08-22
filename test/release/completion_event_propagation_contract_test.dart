import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Completion event propagation contract', () {
    test(
      'event bus fan-out invalidates completion events on task and goal lifecycle updates',
      () {
        final File providerFile = File(
          'lib/state/providers/event_bus_provider.dart',
        );
        expect(providerFile.existsSync(), isTrue);

        final String providerText = SourceTestUtils.readText(providerFile);

        expect(
          providerText.contains(
            "import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';",
          ),
          isTrue,
        );

        expect(
          providerText.contains('bus.on<TaskLifecycleEvent>().listen'),
          isTrue,
        );
        expect(
          providerText.contains('bus.on<GoalLifecycleEvent>().listen'),
          isTrue,
        );
        expect(
          providerText.contains('ref.invalidate(completionEventsProvider);'),
          isTrue,
        );
      },
    );

    test(
      'occurrence completion projection persists before task views invalidate',
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

        final String taskProviderText = SourceTestUtils.readText(
          taskProviderFile,
        );
        final String coordinatorText = SourceTestUtils.readText(
          coordinatorFile,
        );
        final String completionAdapterText = SourceTestUtils.readText(
          completionAdapterFile,
        );

        expect(
          coordinatorText.contains('() => completion.recordTransition('),
          isTrue,
        );
        expect(
          completionAdapterText.contains('await _completionEvents.addEvent('),
          isTrue,
        );
        expect(
          taskProviderText.contains('_invalidateOccurrenceProjections();'),
          isTrue,
        );
        expect(
          taskProviderText.contains(
            '_ref.invalidate(completionEventsProvider);',
          ),
          isTrue,
        );
      },
    );
  });
}
