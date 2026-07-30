// lib/engine/si/si_synthetic_narrative_gravity_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_user_narrative_engine.dart';

class SINarrativeGravity {
  const SINarrativeGravity({
    required this.center,
    required this.pull,
    required this.guidance,
    required this.memory,
  });
  final String center;
  final double pull;
  final String guidance;
  final SIMemoryStore memory;
}

class SISyntheticNarrativeGravityEngine {
  const SISyntheticNarrativeGravityEngine();

  SINarrativeGravity calculate({
    required UserNarrative narrative,
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final pull = siClamp01(
      narrative.confidence * .4 +
          (narrative.trajectory == 'improving' ? .25 : .1) +
          (1 - context.userState.stress) * .25,
    );
    final center = '${narrative.arc}:${narrative.archetype}';
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'narrative_gravity|center=$center|pull=${pull.toStringAsFixed(2)}',
            timestamp: t,
            relevance: pull,
            confidence: .7,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SINarrativeGravity(
      center: center,
      pull: pull,
      guidance: pull >= .65
          ? 'frame_output_with_narrative'
          : 'keep_narrative_subtle',
      memory: next,
    );
  }
}
