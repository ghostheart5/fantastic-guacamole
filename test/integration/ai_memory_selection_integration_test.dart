import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/state/controllers/ai_memory_selection.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI controller memory selection', () {
    test('selectRelevantMemorySummaries prefers query/intent-relevant memory', () {
      final DateTime now = DateTime.utc(2026, 7, 5);
      final List<SISnapshot> snapshots = <SISnapshot>[
        SISnapshot(
          timestamp: now,
          energy: 0.3,
          fatigue: 0.8,
          completed: 4,
          skipped: 2,
          responseSummary: 'Energy is low and fatigue is elevated; prioritize recovery task.',
        ),
        SISnapshot(
          timestamp: now.subtract(const Duration(minutes: 2)),
          energy: 0.7,
          fatigue: 0.2,
          completed: 5,
          skipped: 2,
          responseSummary: 'Focus on task alpha and complete the first block.',
        ),
      ];

      final List<String> selected = selectRelevantMemorySummaries(
        query: 'give me an energy and fatigue check',
        intent: const SIIntent(label: 'energy_check', confidence: 0.9),
        recentSnapshots: snapshots,
        previousState: <String, dynamic>{
          'memoryEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'intent': 'energy_check',
              'summary': 'Energy dipped after late-night session; recover first.',
            },
            <String, dynamic>{
              'intent': 'task_recommendation',
              'summary': 'Pick task beta for next milestone.',
            },
          ],
        },
      );

      expect(selected, isNotEmpty);
      expect(selected.any((s) => s.contains('energy') || s.contains('fatigue')), isTrue);
    });

    test('recentResponseSummaries de-duplicates and caps output', () {
      final DateTime now = DateTime.utc(2026, 7, 5);
      final List<SISnapshot> snapshots = List<SISnapshot>.generate(10, (int i) {
        return SISnapshot(
          timestamp: now.subtract(Duration(minutes: i)),
          energy: 0.5,
          fatigue: 0.5,
          completed: i,
          skipped: 0,
          responseSummary: i.isEven
              ? 'Repeat summary token set'
              : 'Unique summary entry number $i for memory ranking',
        );
      });

      final List<String> summaries = recentResponseSummaries(
        recentSnapshots: snapshots,
        previousState: <String, dynamic>{
          'memoryEvents': <Map<String, dynamic>>[
            <String, dynamic>{'summary': 'Repeat summary token set'},
            <String, dynamic>{'summary': 'Additional memory event summary to include'},
          ],
        },
      );

      expect(summaries.length, lessThanOrEqualTo(12));
      expect(summaries.toSet().length, summaries.length);
      expect(summaries.any((s) => s.contains('additional memory event summary')), isTrue);
    });

    test('selectRelevantMemorySummaries caps result length to eight', () {
      final DateTime now = DateTime.utc(2026, 7, 5);
      final List<SISnapshot> snapshots = List<SISnapshot>.generate(16, (int i) {
        return SISnapshot(
          timestamp: now.subtract(Duration(minutes: i)),
          energy: 0.5,
          fatigue: 0.5,
          completed: i,
          skipped: 0,
          responseSummary: 'Summary $i with task action context',
        );
      });

      final List<String> selected = selectRelevantMemorySummaries(
        query: 'task action next priority',
        intent: const SIIntent(label: 'task_recommendation', confidence: 0.86),
        recentSnapshots: snapshots,
        previousState: const <String, dynamic>{},
      );

      expect(selected.length, lessThanOrEqualTo(8));
    });
  });
}
