import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Completion event propagation contract', () {
    test('event bus fan-out invalidates completion events on task and goal lifecycle updates', () {
      final File providerFile = File('lib/state/providers/event_bus_provider.dart');
      expect(providerFile.existsSync(), isTrue);

      final String providerText = SourceTestUtils.readText(providerFile);

      expect(
        providerText.contains("import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';"),
        isTrue,
      );

      expect(providerText.contains('bus.on<TaskLifecycleEvent>().listen'), isTrue);
      expect(providerText.contains('bus.on<GoalLifecycleEvent>().listen'), isTrue);
      expect(providerText.contains('ref.invalidate(completionEventsProvider);'), isTrue);
    });

    test('task completion event writes invalidate completion events provider after persistence', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String taskProviderText = SourceTestUtils.readText(taskProviderFile);

      expect(
        taskProviderText.contains("import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';"),
        isTrue,
      );

      expect(taskProviderText.contains('await _ref.read(completionEventRepositoryProvider).addEvent(event);'), isTrue);
      expect(taskProviderText.contains('_ref.invalidate(completionEventsProvider);'), isTrue);
    });
  });
}
