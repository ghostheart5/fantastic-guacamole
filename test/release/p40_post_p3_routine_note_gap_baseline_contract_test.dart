import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-0 post-P3 routine/note baseline contract', () {
    test(
      'creator save-kind pathway still preserves task and goal save handling',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('enum CreatorSavedKind { task, goal'), isTrue);
        expect(text.contains('if (intake.kind == IntakeKind.goal)'), isTrue);
        expect(text.contains('return CreatorSavedKind.goal;'), isTrue);
        expect(text.contains("_ => CreatorSavedKind.task"), isTrue);
      },
    );

    test(
      'routine keeps its existing path while Note uses first-class authority',
      () {
        final File creatorProviderFile = File(
          'lib/state/providers/creator_provider.dart',
        );
        expect(creatorProviderFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(creatorProviderFile);

        expect(text.contains('kind: intake.taskKind'), isTrue);
        expect(
          text.contains('recurrence: intake.resolvedRecurrence'),
          isTrue,
        );
        expect(text.contains('Future<void> _createNoteEntry({'), isTrue);
        expect(text.contains("case IntakeKind.note:"), isTrue);
        expect(text.contains('notesProvider.notifier'), isTrue);
        expect(text.contains('.createNote('), isTrue);
        expect(text.contains('note.toTaskEntity('), isFalse);
        expect(text.contains("actionSource: 'creator_note'"), isFalse);
      },
    );

    test(
      'creator form still exposes routine and note through shared task-oriented form flow',
      () {
        final File dynamicFormFile = File(
          'lib/features/creator/widgets/dynamic_form.dart',
        );
        expect(dynamicFormFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(dynamicFormFile);

        expect(text.contains("_selectedType = 'Task';"), isTrue);
        expect(
          text.contains("if (_selectedType.trim().toLowerCase() == 'note')"),
          isTrue,
        );
        expect(text.contains("kind == 'routine' || kind == 'habit'"), isTrue);
        expect(text.contains('CreatorFormData('), isTrue);
        expect(text.contains('type: _entryType,'), isTrue);
        expect(
          text.contains('creatorMode: widget.workspaceMode.name,'),
          isTrue,
        );
      },
    );
  });
}
