import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Creator release protection', () {
    test('creator feature exists and is wired as creation surface', () {
      final Directory dir = Directory('lib/features/creator');
      expect(dir.existsSync(), isTrue);

      final String creatorText = SourceTestUtils.readAllConcatenated('lib/features/creator').toLowerCase();
      expect(creatorText.contains('create') || creatorText.contains('creator'), isTrue);
      expect(creatorText.contains('task') || creatorText.contains('goal') || creatorText.contains('event') || creatorText.contains('note'), isTrue);
    });

    test('creator wiring appears in app navigation', () {
      final String navText = SourceTestUtils.readText(File('lib/app/navigation_shell.dart'));
      expect(navText.contains('CreatorScreen'), isTrue);
      expect(navText.contains('AppView.creator') || navText.contains('creator'), isTrue);
    });

    test('creator ui avoids placeholder text markers', () {
      final List<String> offenders = <String>[];
      const List<String> bad = <String>['Placeholder', 'Coming soon', 'lorem ipsum'];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/features/creator')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('/ui/') && !path.contains('/presentation/')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (bad.any(text.contains)) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Creator UI placeholder markers found: $offenders');
    });
  });
}
