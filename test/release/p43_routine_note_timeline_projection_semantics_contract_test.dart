import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-1 Wave 3 routine/note timeline projection semantics contract', () {
    test(
      'task-to-timeline projection derives semantic kind and title prefixes',
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
        expect(text.contains("'note' => 'Note: \$normalizedTitle'"), isTrue);
      },
    );

    test(
      'task-to-timeline projection provides semantic default details for routine and note',
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
        expect(
          text.contains("'note' => 'Note connected to timeline.'"),
          isTrue,
        );
        expect(text.contains("_ => 'Task connected to timeline.'"), isTrue);
      },
    );

    test(
      'creator routine persistence path now keeps routine kind for projection continuity',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('Future<void> _createRoutineEntry({'), isTrue);
        expect(text.contains("kind: 'routine'"), isTrue);
      },
    );
  });
}
