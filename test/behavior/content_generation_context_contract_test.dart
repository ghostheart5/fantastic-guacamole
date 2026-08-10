import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/state/controllers/ai_memory_selection.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content generation context contract', () {
    test('selectRelevantMemorySummaries enforces count and length limits', () {
      final List<SISnapshot> snapshots = List<SISnapshot>.generate(
        12,
        (int index) => SISnapshot(
          timestamp: DateTime.now().subtract(Duration(minutes: index)),
          energy: 0.6,
          fatigue: 0.3,
          completed: 2,
          skipped: 0,
          responseSummary:
              'This is a long memory summary item number $index with extra details that should be compacted for safe context minimization in content generation.',
        ),
      );

      final List<String> selected = selectRelevantMemorySummaries(
        query: 'help me prioritize next actions and reduce pressure',
        intent: classifySIIntent('what should i do next'),
        recentSnapshots: snapshots,
        previousState: const <String, dynamic>{},
      );

      expect(selected.length, lessThanOrEqualTo(6));
      expect(selected.every((String item) => item.length <= 123), isTrue);
    });

    test('recentResponseSummaries keeps bounded compact output', () {
      final List<SISnapshot> snapshots = List<SISnapshot>.generate(
        20,
        (int index) => SISnapshot(
          timestamp: DateTime.now().subtract(Duration(minutes: index)),
          energy: 0.7,
          fatigue: 0.2,
          completed: 3,
          skipped: 0,
          responseSummary: 'Response summary $index for bounded context.',
        ),
      );

      final List<String> recent = recentResponseSummaries(
        recentSnapshots: snapshots,
        previousState: const <String, dynamic>{
          'memoryEvents': <Map<String, dynamic>>[
            <String, dynamic>{'summary': 'Extra memory event summary one'},
            <String, dynamic>{'summary': 'Extra memory event summary two'},
          ],
        },
      );

      expect(recent.length, lessThanOrEqualTo(6));
    });
  });
}
