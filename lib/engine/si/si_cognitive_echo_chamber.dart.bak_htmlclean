// lib/engine/si/si_cognitive_echo_chamber.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class EchoChamberReport {
  const EchoChamberReport({
    required this.detected,
    required this.repetitionScore,
    required this.repeatedTerms,
    required this.recommendation,
    required this.memory,
  });

  final bool detected;
  final double repetitionScore;
  final List<String> repeatedTerms;
  final String recommendation;
  final SIMemoryStore memory;
}

class SICognitiveEchoChamber {
  const SICognitiveEchoChamber();

  EchoChamberReport detect({
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<String> terms = <String>[];

    for (final MemoryRecord r in memory.tiered.shortTerm.take(12)) {
      terms.addAll(
        siClean(r.content)
            .toLowerCase()
            .split(RegExp(r'[^a-z0-9_]+'))
            .where((String x) => x.length > 4),
      );
    }

    final Map<String, int> counts = <String, int>{};
    for (final String term in terms) {
      counts[term] = (counts[term] ?? 0) + 1;
    }

    final List<String> repeated = counts.entries
        .where((MapEntry<String, int> e) => e.value >= 3)
        .map((MapEntry<String, int> e) => e.key)
        .take(8)
        .toList();

    final double score = siClamp01(repeated.length / 8);
    final bool detected = score >= 0.35;

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'echo_chamber|detected=$detected|terms=${repeated.join(",")}',
            timestamp: t,
            relevance: score,
            confidence: 0.66,
            emotionalWeight: detected ? 0.58 : 0.3,
            reinforcement: detected ? 0 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return EchoChamberReport(
      detected: detected,
      repetitionScore: score,
      repeatedTerms: List<String>.unmodifiable(repeated),
      recommendation: detected
          ? 'Introduce fresh framing while staying grounded.'
          : 'No repetition loop detected.',
      memory: next,
    );
  }
}
