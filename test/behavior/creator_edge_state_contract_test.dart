import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Creator edge-state contract', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/creator/ui/creator_screen.dart',
      ).readAsStringSync();
    });

    test('voice handoff application is deduplicated by timestamp', () {
      expect(source, contains('_lastAppliedHandoffAt'));
      expect(source, contains('if (_lastAppliedHandoffAt == handoff.createdAt)'));
      expect(source, contains('_lastAppliedHandoffAt = handoff.createdAt'));
    });

    test('voice handoff can switch workspace mode safely', () {
      expect(source, contains('if (_mode != targetMode)'));
      expect(source, contains('WidgetsBinding.instance.addPostFrameCallback'));
      expect(source, contains('_mode = targetMode'));
    });

    test('submit flow preserves create-to-timeline review loop', () {
      expect(source, contains('creatorActionsProvider'));
      expect(source, contains('shouldAutoOpenTimeline'));
      expect(source, contains('toTimeline()'));
      expect(source, contains('REVIEW TIMELINE'));
    });
  });
}
