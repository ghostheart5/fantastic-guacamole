import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-2 timeline readability hierarchy contract', () {
    test('timeline day grouping uses normalized dates and sorted day buckets', () {
      final File timelineScreenFile = File('lib/features/timeline/ui/timeline_screen.dart');
      expect(timelineScreenFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(timelineScreenFile);

      expect(text.contains('final Map<DateTime, List<TimelineEventEntity>> grouped ='), isTrue);
      expect(text.contains('final DateTime day = _normalizedDay(_eventMoment(event));'), isTrue);
      expect(text.contains('final List<DateTime> days = grouped.keys.toList(growable: false)'), isTrue);
      expect(text.contains('..sort((a, b) => b.compareTo(a));'), isTrue);
    });

    test('timeline day headers include relative labels and per-day item counts', () {
      final File timelineScreenFile = File('lib/features/timeline/ui/timeline_screen.dart');
      expect(timelineScreenFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(timelineScreenFile);

      expect(text.contains("return 'Today';"), isTrue);
      expect(text.contains("return 'Yesterday';"), isTrue);
      expect(text.contains("return 'Tomorrow';"), isTrue);
      expect(text.contains("? '1 item'"), isTrue);
      expect(text.contains(": '\${dayEvents.length} items';"), isTrue);
      expect(text.contains('DateTimeFormats.timelineDay(day);'), isTrue);
    });
  });
}
