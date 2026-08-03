import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-4 connector workflow contract', () {
    test('creator actions stay wired to canonical task and goal entry points', () {
      final File creatorFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorFile);

      expect(text.contains('Future<CreatorSavedKind> createEntry(CreatorFormData data) async {'), isTrue);
      expect(text.contains("await _createGoal(data: data, recurrence: recurrence);"), isTrue);
      expect(text.contains(".read(taskActionsProvider)"), isTrue);
      expect(text.contains('.createTask(entity, actionSource:'), isTrue);
      expect(text.contains('await _markFirstItemCreated();'), isTrue);
      expect(text.contains('goalsProvider.notifier'), isTrue);
    });

    test('task and goal fan-out remain connected to timeline, logs, and lifecycle events', () {
      final File taskFile = File('lib/state/providers/task_provider.dart');
      final File goalsFile = File('lib/state/providers/goals_provider.dart');
      expect(taskFile.existsSync(), isTrue);
      expect(goalsFile.existsSync(), isTrue);

      final String taskText = SourceTestUtils.readText(taskFile);
      final String goalsText = SourceTestUtils.readText(goalsFile);

      expect(taskText.contains('connectTask(normalized)'), isTrue);
      expect(taskText.contains("addMirroredEntry(source: 'task_created'"), isTrue);
      expect(taskText.contains('completionEventRepositoryProvider).addEvent(event);'), isTrue);
      expect(taskText.contains('TaskLifecycleEvent('), isTrue);

      expect(goalsText.contains('addMirroredEntry(source: \'goal_\$actionName\''), isTrue);
      expect(goalsText.contains('addMirroredEvent('), isTrue);
      expect(goalsText.contains('GoalLifecycleEvent('), isTrue);
    });

    test('timeline connector layer keeps usecase boundaries and event bus emission', () {
      final File timelineFile = File('lib/state/providers/timeline_provider.dart');
      expect(timelineFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(timelineFile);

      expect(text.contains('connectTimelineToGoalsUsecaseProvider'), isTrue);
      expect(text.contains('connectTimelineToTasksUsecaseProvider'), isTrue);
      expect(text.contains('connectTimelineToHabitsUsecaseProvider'), isTrue);
      expect(text.contains('connectTimelineToProjectsUsecaseProvider'), isTrue);
      expect(text.contains('TimelineLifecycleEvent('), isTrue);
      expect(text.contains('.read(eventBusProvider)'), isTrue);
    });

    test('core workflow providers avoid direct network connector calls', () {
      final List<String> providerPaths = <String>[
        'lib/state/providers/creator_provider.dart',
        'lib/state/providers/task_provider.dart',
        'lib/state/providers/goals_provider.dart',
        'lib/state/providers/timeline_provider.dart',
      ];

      for (final String path in providerPaths) {
        final File file = File(path);
        expect(file.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(file);

        expect(text.contains('http.'), isFalse, reason: 'Direct HTTP usage found in $path');
        expect(text.contains('Dio('), isFalse, reason: 'Direct Dio usage found in $path');
        expect(
          text.contains('Supabase.instance.client.from('),
          isFalse,
          reason: 'Direct Supabase table connector usage found in $path',
        );
      }
    });
  });
}
