// lib/engine/si/si_synthetic_alignment_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIAlignmentResult {
  const SIAlignmentResult({
    required this.aligned,
    required this.score,
    required this.guidance,
    required this.memory,
  });
  final bool aligned;
  final double score;
  final String guidance;
  final SIMemoryStore memory;
}

class SISyntheticAlignmentEngine {
  const SISyntheticAlignmentEngine();

  SIAlignmentResult evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    SIDecision? decision,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final score = siClamp01(
      intent.confidence * .28 +
          (1 - context.userState.stress) * .22 +
          (1 - context.userState.cognitiveLoad) * .2 +
          (decision?.safe == false ? 0 : .2) +
          (instinct.safetyFirst ? .1 : .2),
    );
    final guidance = score >= .7
        ? 'aligned_action'
        : instinct.safetyFirst
        ? 'stabilize_first'
        : 'clarify_then_act';
    final next = _write(
      memory,
      t,
      'synthetic_alignment|score=${score.toStringAsFixed(2)}|$guidance',
      score,
      context.userState.stress,
    );
    return SIAlignmentResult(
      aligned: score >= .62,
      score: score,
      guidance: guidance,
      memory: next,
    );
  }

  SIMemoryStore _write(
    SIMemoryStore m,
    DateTime t,
    String c,
    double r,
    double e,
  ) => m
      .pushRecord(
        MemoryTier.shortTerm,
        MemoryRecord(
          content: c,
          timestamp: t,
          relevance: r,
          confidence: .72,
          emotionalWeight: siClamp01(e),
          reinforcement: r >= .7 ? 1 : 0,
        ),
      )
      .dedupe()
      .decay(t);
}
