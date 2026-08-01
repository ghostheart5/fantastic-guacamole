import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P1-1 future and ascension completion signal contract', () {
    test('intelligence fusion watches completion events for rationale context', () {
      final File file = File('lib/state/providers/intelligence_fusion_provider.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(
        text.contains("import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';"),
        isTrue,
      );
      expect(text.contains('final completionEvents = ref.watch(completionEventsProvider);'), isTrue);
      expect(text.contains('Completion signal'), isTrue);
    });

    test('future timeline uses completion events to shape near-term prediction context', () {
      final File file = File('lib/state/providers/future_timeline_provider.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(
        text.contains("import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';"),
        isTrue,
      );
      expect(text.contains('final completionEvents = ref.watch(completionEventsProvider);'), isTrue);
      expect(text.contains('completedCount'), isTrue);
      expect(text.contains('deferralCount'), isTrue);
    });
  });
}
