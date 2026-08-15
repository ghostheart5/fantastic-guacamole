import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-1 Wave 2 routine/note runtime routing split contract', () {
    test(
      'createEntry routes requested routine and note kinds through dedicated handlers',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('switch (intake.kind) {'), isTrue);
        expect(text.contains('case IntakeKind.routine:'), isTrue);
        expect(text.contains('await _createRoutineEntry('), isTrue);
        expect(text.contains('case IntakeKind.note:'), isTrue);
        expect(text.contains('await _createNoteEntry('), isTrue);
        expect(text.contains('await _createTaskEntry('), isTrue);
      },
    );

    test(
      'routine handler preserves its dedicated canonical task action path',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);
        final String intake = SourceTestUtils.readText(
          File('lib/domain/intake/intake_request.dart'),
        );

        expect(text.contains('Future<void> _createRoutineEntry({'), isTrue);
        expect(text.contains("actionSource: 'creator_routine'"), isTrue);
        expect(
          intake.contains("'routine' || 'daily rhythm' || 'habit' => IntakeKind.routine"),
          isTrue,
          reason:
              'All user-facing daily-rhythm aliases must reach the dedicated routine handler.',
        );
      },
    );

    test(
      'note handler persists only through the first-class Note authority',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('Future<void> _createNoteEntry({'), isTrue);
        expect(text.contains('notesProvider.notifier'), isTrue);
        expect(text.contains('.createNote(title: data.title, body: data.description)'), isTrue);
        expect(text.contains('note.toTaskEntity('), isFalse);
        expect(text.contains("actionSource: 'creator_note'"), isFalse);
      },
    );
  });
}
