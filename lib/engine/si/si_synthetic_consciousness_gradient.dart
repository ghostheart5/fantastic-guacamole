// lib/engine/si/si_synthetic_consciousness_gradient.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_consciousness_field.dart';

class SIConsciousnessGradient {
  const SIConsciousnessGradient({
    required this.direction,
    required this.slope,
    required this.recommendation,
    required this.memory,
  });
  final String direction;
  final double slope;
  final String recommendation;
  final SIMemoryStore memory;
}

class SISyntheticConsciousnessGradient {
  const SISyntheticConsciousnessGradient();

  SIConsciousnessGradient derive({
    required SIConsciousnessField field,
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final slope = siClamp01(
      field.coherence - context.userState.stress * .35 + field.awareness * .2,
    );
    final dir = slope >= .65
        ? 'toward_action'
        : slope <= .35
        ? 'toward_stabilization'
        : 'toward_clarity';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'consciousness_gradient|$dir|slope=${slope.toStringAsFixed(2)}',
            timestamp: t,
            relevance: slope,
            confidence: .7,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIConsciousnessGradient(
      direction: dir,
      slope: slope,
      recommendation: dir == 'toward_action'
          ? 'act_concisely'
          : dir == 'toward_stabilization'
          ? 'reduce_pressure'
          : 'ask_one_detail',
      memory: next,
    );
  }
}
