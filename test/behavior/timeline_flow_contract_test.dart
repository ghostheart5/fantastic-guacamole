import 'dart:io';

import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Timeline flow contract', () {
    test('Timeline screen is importable', () {
      const Widget widget = TimelineScreen();
      expect(widget, isA<TimelineScreen>());
    });

    test('Timeline feature includes history/activity/event data paths', () {
      final String timeline = SourceTestUtils.readAllConcatenated('lib/features/timeline').toLowerCase();
      expect(timeline.contains('event'), isTrue);
      expect(timeline.contains('history') || timeline.contains('activity'), isTrue);
    });

    test('Timeline is sole explicit history surface in ui screen naming', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/features')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        final bool isTimelinePath = path.contains('/timeline/');
        final bool historyScreen = path.contains('history') && path.contains('screen');
        final bool isCreditHistory = path.contains('credit_history');
        if (historyScreen && !isTimelinePath && !isCreditHistory) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'History surface appears outside timeline feature: $offenders');
    });

    test('Timeline wiring references provider or repository contracts', () {
      final String timelineScreen = SourceTestUtils.readText(File('lib/features/timeline/ui/timeline_screen.dart')).toLowerCase();
      expect(timelineScreen.contains('timelineprovider'), isTrue);
      expect(timelineScreen.contains('provider'), isTrue);
    });
  });
}
