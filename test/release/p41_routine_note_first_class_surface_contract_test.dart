import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-1 routine/note first-class surface contract', () {
    test('creator saved kind enum exposes routine and note categories', () {
      final File creatorProviderFile = File(
        'lib/state/providers/creator_provider.dart',
      );
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(
        text.contains('enum CreatorSavedKind { task, goal, routine, note }'),
        isTrue,
      );
    });

    test(
      'create entry captures requested kind and returns distinct save kind',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('final intake = IntakeRequest.fromRaw'), isTrue);
        expect(
          text.contains(
            'return _savedKindFor(requestedKind: intake.kind.name);',
          ),
          isTrue,
        );
        expect(text.contains("'routine' => CreatorSavedKind.routine"), isTrue);
        expect(text.contains("'note' => CreatorSavedKind.note"), isTrue);
      },
    );

    test(
      'creator screen records task metrics only for task-backed save kinds',
      () {
        final File creatorScreenFile = File(
          'lib/features/creator/ui/creator_screen.dart',
        );
        expect(creatorScreenFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorScreenFile);

        expect(text.contains('savedKind == CreatorSavedKind.task ||'), isTrue);
        expect(text.contains('savedKind == CreatorSavedKind.routine)'), isTrue);
        final int metricsStart = text.indexOf(
          'if (savedKind == CreatorSavedKind.task ||',
        );
        final int metricsEnd = text.indexOf('ref.invalidate(tasksProvider);');
        final String metricsBlock = text.substring(metricsStart, metricsEnd);
        expect(metricsBlock.contains('CreatorSavedKind.note'), isFalse);
        expect(text.contains('.recordTaskCreated();'), isTrue);
        expect(text.contains("CreatorSavedKind.note => 'Note saved.'"), isTrue);
      },
    );
  });
}
