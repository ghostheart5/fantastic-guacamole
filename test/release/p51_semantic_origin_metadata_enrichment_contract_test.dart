import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P5-1 Wave 2 semantic-origin metadata enrichment contract', () {
    test('creator provider routes semantic actionSource values by requested kind', () {
      final File creatorProviderFile = File('lib/state/providers/creator_provider.dart');
      expect(creatorProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorProviderFile);

      expect(text.contains("actionSource: 'creator_task'"), isTrue);
      expect(text.contains("actionSource: 'creator_routine'"), isTrue);
      expect(text.contains("actionSource: 'creator_note'"), isTrue);
    });

    test('task provider emits semantic creation reflection for routine and note', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(taskProviderFile);

      expect(text.contains("'routine' => 'Routine Added'"), isTrue);
      expect(text.contains("'note' => 'Note Added'"), isTrue);
      expect(text.contains("'routine' => '\${task.title} routine added to trajectory.'"), isTrue);
      expect(text.contains("'note' => '\${task.title} note added to trajectory.'"), isTrue);
    });

    test('completion telemetry metadata includes task kind field', () {
      final File taskProviderFile = File('lib/state/providers/task_provider.dart');
      expect(taskProviderFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(taskProviderFile);

      expect(text.contains("'kind': task.kind,"), isTrue);
    });
  });
}
