// lib/engine/si/si_synthetic_instinct_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';

class SyntheticInstinctAdvice {
  const SyntheticInstinctAdvice({
    required this.suggestSafetyFirst,
    required this.suggestClarify,
    required this.suggestReduceOutput,
    required this.suggestEncourageProgress,
    required this.reason,
    required this.confidence,
    required this.memory,
  });

  final bool suggestSafetyFirst;
  final bool suggestClarify;
  final bool suggestReduceOutput;
  final bool suggestEncourageProgress;
  final String reason;
  final double confidence;
  final SIMemoryStore memory;
}

class SISyntheticInstinctSystem {
  const SISyntheticInstinctSystem();

  SyntheticInstinctAdvice advise({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    AttentionProfile? attention,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final double stress = siClamp01(context.userState.stress);
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double intentConfidence = siClamp01(intent.confidence);
    final double attentionScore = siClamp01(
      attention?.focusScore ?? intentConfidence,
    );

    final bool safety = instinct.safetyFirst || stress >= 0.72 || load >= 0.78;
    final bool clarify =
        instinct.reduceConfusion ||
        intentConfidence < 0.52 ||
        attentionScore < 0.45;
    final bool reduce =
        instinct.avoidOverwhelm || load >= 0.7 || stress >= 0.65;
    final bool progress = !safety && !reduce && intentConfidence >= 0.58;

    final String reason = _reason(
      safety: safety,
      clarify: clarify,
      reduce: reduce,
      progress: progress,
    );

    final double confidence = siClamp01(
      (intentConfidence * 0.35) +
          ((1 - stress) * 0.2) +
          ((1 - load) * 0.2) +
          (attentionScore * 0.25),
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_instinct|safety=$safety|clarify=$clarify|reduce=$reduce|progress=$progress|$reason',
            timestamp: timestamp,
            relevance: confidence,
            confidence: confidence,
            emotionalWeight: siClamp01((stress + load) / 2),
            reinforcement: progress ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return SyntheticInstinctAdvice(
      suggestSafetyFirst: safety,
      suggestClarify: clarify,
      suggestReduceOutput: reduce,
      suggestEncourageProgress: progress,
      reason: reason,
      confidence: confidence,
      memory: nextMemory,
    );
  }

  String _reason({
    required bool safety,
    required bool clarify,
    required bool reduce,
    required bool progress,
  }) {
    if (safety) return 'Synthetic instinct recommends safety-first pacing.';
    if (clarify) return 'Synthetic instinct recommends clarification.';
    if (reduce) return 'Synthetic instinct recommends reduced output load.';
    if (progress) return 'Synthetic instinct supports action-focused progress.';
    return 'Synthetic instinct recommends steady neutral guidance.';
  }
}
