import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';

List<String> recentResponseSummaries({
  required List<SISnapshot> recentSnapshots,
  required Map<String, dynamic>? previousState,
}) {
  final List<String> summaries = recentSnapshots
      .map((SISnapshot snapshot) => snapshot.responseSummary)
      .whereType<String>()
      .where((String summary) => summary.trim().isNotEmpty)
      .toList(growable: true);

  final dynamic rawEvents = previousState?['memoryEvents'];
  if (rawEvents is List<dynamic>) {
    for (final dynamic event in rawEvents) {
      if (event is Map<dynamic, dynamic>) {
        final String summary = event['summary']?.toString().trim() ?? '';
        if (summary.isNotEmpty) {
          summaries.add(summary);
        }
      }
    }
  }

  final Set<String> deduped = summaries
      .map((String s) => responseSummaryFor(s, maxWords: 20))
      .where((String s) => s.isNotEmpty)
      .toSet();
  return deduped.take(12).toList(growable: false);
}

List<String> selectRelevantMemorySummaries({
  required String query,
  required SIIntent intent,
  required List<SISnapshot> recentSnapshots,
  required Map<String, dynamic>? previousState,
}) {
  final String normalizedQuery = responseSummaryFor(query, maxWords: 24);
  final Set<String> seen = <String>{};
  final List<_ScoredMemory> scored = <_ScoredMemory>[];

  for (int i = 0; i < recentSnapshots.length; i++) {
    final SISnapshot snapshot = recentSnapshots[i];
    final String text = snapshot.responseSummary?.trim() ?? '';
    if (text.isEmpty) {
      continue;
    }
    final String normalized = responseSummaryFor(text, maxWords: 20);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    final double recencyScore =
        (recentSnapshots.length - i) / recentSnapshots.length;
    final double relevanceScore = _queryOverlapScore(
      normalizedQuery,
      normalized,
    );
    final double intentScore = _intentAffinityScore(intent.label, normalized);
    scored.add(
      _ScoredMemory(
        text: normalized,
        score:
            (recencyScore * 0.5) +
            (relevanceScore * 0.35) +
            (intentScore * 0.15),
      ),
    );
  }

  final dynamic rawEvents = previousState?['memoryEvents'];
  if (rawEvents is List<dynamic>) {
    for (final dynamic event in rawEvents) {
      if (event is! Map<dynamic, dynamic>) {
        continue;
      }
      final String summary = event['summary']?.toString().trim() ?? '';
      if (summary.isEmpty) {
        continue;
      }
      final String normalized = responseSummaryFor(summary, maxWords: 20);
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      final String eventIntent = event['intent']?.toString().trim() ?? '';
      final double relevanceScore = _queryOverlapScore(
        normalizedQuery,
        normalized,
      );
      final double intentScore = eventIntent == intent.label
          ? 1.0
          : _intentAffinityScore(intent.label, normalized);
      scored.add(
        _ScoredMemory(
          text: normalized,
          score: (relevanceScore * 0.65) + (intentScore * 0.35),
        ),
      );
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(8).map((entry) => entry.text).toList(growable: false);
}

double _queryOverlapScore(String query, String memory) {
  final Set<String> queryTokens = query
      .split(' ')
      .where((String token) => token.length >= 3)
      .toSet();
  final Set<String> memoryTokens = memory
      .split(' ')
      .where((String token) => token.length >= 3)
      .toSet();
  if (queryTokens.isEmpty || memoryTokens.isEmpty) {
    return 0;
  }
  final int overlap = queryTokens.intersection(memoryTokens).length;
  final int union = queryTokens.union(memoryTokens).length;
  return union == 0 ? 0 : overlap / union;
}

double _intentAffinityScore(String intent, String memory) {
  switch (intent) {
    case 'task_recommendation':
      return _queryOverlapScore('task action next priority', memory);
    case 'energy_check':
      return _queryOverlapScore('energy fatigue mood recovery', memory);
    case 'status':
      return _queryOverlapScore('status summary overview progress', memory);
    default:
      return _queryOverlapScore('coach guidance focus', memory);
  }
}

class _ScoredMemory {
  const _ScoredMemory({required this.text, required this.score});

  final String text;
  final double score;
}
