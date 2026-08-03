import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P4-1 Wave 2 routine/note runtime routing split contract', () {
    test('createEntry routes requested routine and note kinds through dedicated handlers', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains('switch (requestedKind.trim().toLowerCase()) {'), isTrue);
      expect(text.contains("case 'routine':"), isTrue);
      expect(text.contains('await _createRoutineEntry(data: data, recurrence: recurrence);'), isTrue);
      expect(text.contains("case 'note':"), isTrue);
      expect(text.contains('await _createNoteEntry(data: data, recurrence: recurrence);'), isTrue);
      expect(text.contains('await _createTaskEntry(data: data, kind: kind, recurrence: recurrence);'), isTrue);
    });

    test('routine handler preserves dedicated routine kind on task persistence path', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains('Future<void> _createRoutineEntry({'), isTrue);
      expect(text.contains("kind: 'routine'"), isTrue);
    });

    test('note handler preserves note-to-task conversion persistence behavior', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains('Future<void> _createNoteEntry({'), isTrue);
      expect(text.contains('final TaskEntity entity = note.toTaskEntity('), isTrue);
      expect(text.contains('.createTask(entity, actionSource: _legacyCreatorNoteActionSource);'), isTrue);
    });
  });
}
