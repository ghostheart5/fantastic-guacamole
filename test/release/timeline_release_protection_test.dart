import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Timeline release protection', () {
    test('timeline source exists and carries activity history semantics', () {
      final Directory dir = Directory('lib/features/timeline');
      expect(dir.existsSync(), isTrue);

      final String text = SourceTestUtils.readAllConcatenated(
        'lib/features/timeline',
      ).toLowerCase();
      expect(text.contains('timeline'), isTrue);
      expect(
        text.contains('history') ||
            text.contains('activity') ||
            text.contains('event'),
        isTrue,
      );
    });

    test(
      'duplicate generic history screens are not introduced outside timeline',
      () {
        final List<String> offenders = <String>[];

        for (final File file in SourceTestUtils.dartFilesUnder(
          'lib/features',
        )) {
          final String path = SourceTestUtils.normalizePath(
            file.path,
          ).toLowerCase();
          if (!path.contains('history') || !path.contains('screen')) {
            continue;
          }
          if (path.contains('/timeline/')) {
            continue;
          }
          if (path.contains('credit_history')) {
            continue;
          }
          offenders.add(path);
        }

        expect(
          offenders,
          isEmpty,
          reason: 'History screen drift detected outside timeline: $offenders',
        );
      },
    );

    test('timeline has provider/repository wiring references', () {
      final String text = SourceTestUtils.readText(
        File('lib/features/timeline/ui/timeline_screen.dart'),
      ).toLowerCase();
      expect(text.contains('provider'), isTrue);
      expect(
        text.contains('timelineprovider') || text.contains('timeline_provider'),
        isTrue,
      );
    });

    test('timeline preserves explicit not-completed workflow semantics', () {
      final String text = SourceTestUtils.readText(
        File('lib/features/timeline/ui/timeline_screen.dart'),
      ).toLowerCase();
      expect(text.contains('not completed'), isTrue);
      expect(text.contains("delayreason: 'not_completed'"), isTrue);
    });

    test('workflow signal taxonomy includes task_not_completed handling', () {
      final String taskProvider = SourceTestUtils.readText(
        File('lib/state/providers/task_provider.dart'),
      ).toLowerCase();
      final String executionSignals = SourceTestUtils.readText(
        File('lib/state/providers/execution_signals_provider.dart'),
      ).toLowerCase();

      expect(taskProvider.contains('task_not_completed'), isTrue);
      expect(executionSignals.contains('task_not_completed'), isTrue);
    });
  });
}
