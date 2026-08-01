import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P5-0 post-P4 semantic-origin gap baseline contract', () {
    test('creator persistence path still emits generic creator actionSource', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains(".createTask(entity, actionSource: 'creator');"), isTrue);
    });

    test('task creation side effects still publish generic task-added reflection event', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(taskProviderFile);

      expect(text.contains("title: 'Task Added'"), isTrue);
      expect(text.contains("detail: '\${task.title} added to trajectory.'"), isTrue);
    });

    test('completion event metadata baseline does not yet include task kind', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(taskProviderFile);

      expect(text.contains("'title': task.title,"), isTrue);
      expect(text.contains("'priority': task.priority,"), isTrue);
      expect(text.contains("'difficulty': task.difficulty,"), isTrue);
      expect(text.contains("'kind': task.kind,"), isFalse);
    });
  });
}
