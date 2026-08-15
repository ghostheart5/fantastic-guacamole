import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-1 Wave 3 routine/note timeline projection semantics contract', () {
    test(
      'task-to-timeline projection remains Task-only while Notes are deferred',
      () {
        final File connectUsecaseFile = File(
          'lib/features/auth/domain/usecases/misc/connect_timeline_to_tasks_usecase.dart',
        );
        expect(connectUsecaseFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(connectUsecaseFile);

        expect(
          text.contains(
            'final String projectionKind = _projectionKindFor(task.kind);',
          ),
          isTrue,
        );
        expect(
          text.contains("'routine' || 'habit' => 'Habit: \$normalizedTitle'"),
          isTrue,
        );
        expect(text.contains("'note' => 'Note: \$normalizedTitle'"), isTrue,
            reason: 'Historical Task kind projection is not Note authority.');
      },
    );

    test(
      'task-to-timeline projection retains Task semantics without canonical Note storage',
      () {
        final File connectUsecaseFile = File(
          'lib/features/auth/domain/usecases/misc/connect_timeline_to_tasks_usecase.dart',
        );
        expect(connectUsecaseFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(connectUsecaseFile);

        expect(
          text.contains(
            "'routine' || 'habit' => 'Habit connected to timeline.'",
          ),
          isTrue,
        );
        expect(text.contains('NoteRepository'), isFalse);
        expect(text.contains("_ => 'Task connected to timeline.'"), isTrue);
      },
    );

    test(
      'creator routine persistence path remains separate from first-class Notes',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('Future<void> _createRoutineEntry({'), isTrue);
        expect(text.contains("actionSource: 'creator_routine'"), isTrue);
        expect(text.contains('NoteRepository'), isFalse);
      },
    );
  });
}
