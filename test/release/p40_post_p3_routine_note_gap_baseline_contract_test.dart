import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-0 post-P3 routine/note baseline contract', () {
    test('creator save-kind pathway still preserves task and goal save handling', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains('enum CreatorSavedKind { task, goal'), isTrue);
      expect(text.contains("if (kind == 'goal') {"), isTrue);
      expect(text.contains('return CreatorSavedKind.goal;'), isTrue);
      expect(text.contains("_ => CreatorSavedKind.task"), isTrue);
    });

    test('routine and note intent currently normalize into habit/task pathways', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains("'routine' => 'habit'"), isTrue);
      expect(text.contains("'routine' || 'habit' => RecurrenceRule.daily"), isTrue);
      expect(text.contains("if (kind == 'note') {"), isTrue);
      expect(text.contains('note.toTaskEntity('), isTrue);
      expect(text.contains(".createTask(entity, actionSource: 'creator');"), isTrue);
    });

    test('creator form still exposes routine and note through shared task-oriented form flow', () {
      final File dynamicFormFile = File('lib/features/creator/widgets/dynamic_form.dart');
      expect(dynamicFormFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(dynamicFormFile);

      expect(text.contains("_selectedType = 'Task';"), isTrue);
      expect(text.contains("if (_selectedType.trim().toLowerCase() == 'note')"), isTrue);
      expect(text.contains("kind == 'routine' || kind == 'habit'"), isTrue);
      expect(text.contains('CreatorFormData('), isTrue);
      expect(text.contains('type: _entryType,'), isTrue);
      expect(text.contains('creatorMode: widget.workspaceMode.name,'), isTrue);
    });
  });
}
