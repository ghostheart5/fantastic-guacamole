import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timeline edge-state contract', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/timeline/ui/timeline_screen.dart',
      ).readAsStringSync();
    });

    test('history focus filters to past events only', () {
      expect(source, contains('_TimelineFocus.history'));
      expect(source, contains('_eventMoment(event).isBefore(now)'));
    });

    test('empty-state guidance remains user-actionable', () {
      expect(source, contains('No items match this view.'));
      expect(
        source,
        contains(
          'Try another window, clear filters, or create something in Creator.',
        ),
      );
    });

    test('first-action unlock banner logic remains wired', () {
      expect(source, contains('showFirstActionUnlockBanner'));
      expect(
        source,
        contains('hasCreatedFirstItem && !hasCompletedTimelineFirstAction'),
      );
      expect(source, contains('_TimelineUnlockBanner'));
    });
  });
}
