import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P5-0 post-P4 semantic-origin gap baseline contract', () {
    test(
      'creator persistence path emits creator-scoped actionSource markers',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains("actionSource: 'creator_task'"), isTrue);
        expect(text.contains("actionSource: 'creator_routine'"), isTrue);
        expect(text.contains("actionSource: 'creator_note'"), isTrue);
      },
    );

    test(
      'task creation side effects still publish trajectory reflection events',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);

        expect(text.contains('title: reflectionTitle,'), isTrue);
        expect(text.contains('detail: reflectionDetail,'), isTrue);
        expect(text.contains("'Task Added'"), isTrue);
      },
    );

    test(
      'completion event metadata includes task kind for semantic continuity',
      () {
        final File taskProviderFile = File(
          'lib/state/providers/task_provider.dart',
        );
        expect(taskProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(taskProviderFile);

        expect(text.contains("'title': task.title,"), isTrue);
        expect(text.contains("'priority': task.priority,"), isTrue);
        expect(text.contains("'difficulty': task.difficulty,"), isTrue);
        expect(text.contains("'kind': task.kind,"), isTrue);
      },
    );
  });
}
