import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  test('Creator Note has no Task, Timeline, reminder, or progression write path', () {
    final String creator = SourceTestUtils.readText(File('lib/state/providers/creator_provider.dart'));
    final String screen = SourceTestUtils.readText(File('lib/features/creator/ui/creator_screen.dart'));
    expect(creator.contains('notesProvider.notifier'), isTrue);
    expect(creator.contains("actionSource: 'creator_note'"), isFalse);
    expect(creator.contains('toTaskEntity('), isFalse);
    expect(screen.contains('savedKind == CreatorSavedKind.note) {\n                          await ref\n                              .read(localMetricsAccumulatorProvider)'), isFalse);
  });
}
