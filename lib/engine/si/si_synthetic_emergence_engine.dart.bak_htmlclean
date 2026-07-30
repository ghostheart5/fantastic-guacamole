// lib/engine/si/si_synthetic_emergence_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIEmergenceSignal {
  const SIEmergenceSignal({
    required this.detected,
    required this.score,
    required this.label,
    required this.memory,
  });
  final bool detected;
  final double score;
  final String label;
  final SIMemoryStore memory;
}

class SISyntheticEmergenceEngine {
  const SISyntheticEmergenceEngine();

  SIEmergenceSignal detect({
    required SIContext context,
    required SIIntent intent,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final score = siClamp01(
      intent.confidence * .25 +
          context.userState.engagement * .25 +
          memory.tiered.shortTerm.length.clamp(0, 10) / 10 * .25 +
          context.userState.motivation * .25,
    );
    final label = score >= .7
        ? 'strong_signal_cluster'
        : score >= .5
        ? 'forming_signal_cluster'
        : 'low_emergence';
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'synthetic_emergence|$label|score=${score.toStringAsFixed(2)}',
            timestamp: t,
            relevance: score,
            confidence: .68,
            emotionalWeight: context.userState.stress,
            reinforcement: score >= .7 ? 2 : 0,
          ),
        )
        .dedupe()
        .decay(t);
    return SIEmergenceSignal(
      detected: score >= .55,
      score: score,
      label: label,
      memory: next,
    );
  }
}
