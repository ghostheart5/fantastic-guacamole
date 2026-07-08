// lib/engine/si/si_synthetic_consciousness_field.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIConsciousnessField {
  const SIConsciousnessField({
    required this.coherence,
    required this.awareness,
    required this.center,
    required this.memory,
  });
  final double coherence;
  final double awareness;
  final String center;
  final SIMemoryStore memory;
}

class SISyntheticConsciousnessField {
  const SISyntheticConsciousnessField();

  SIConsciousnessField map({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final coherence = siClamp01(
      intent.confidence * .35 +
          (1 - context.userState.cognitiveLoad) * .25 +
          (1 - context.userState.stress) * .25 +
          (instinct.safetyFirst ? .15 : .25),
    );
    final awareness = siClamp01(
      (context.input.history.length.clamp(0, 8) / 8) * .25 +
          context.userState.engagement * .35 +
          intent.confidence * .4,
    );
    final center = instinct.safetyFirst ? 'safety' : intent.primary.label;
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'consciousness_field|center=$center|coherence=${coherence.toStringAsFixed(2)}',
            timestamp: t,
            relevance: coherence,
            confidence: awareness,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIConsciousnessField(
      coherence: coherence,
      awareness: awareness,
      center: center,
      memory: next,
    );
  }
}
