// lib/engine/si/si_synthetic_identity_gradient.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIIdentityGradient {
  const SIIdentityGradient({
    required this.weights,
    required this.dominant,
    required this.memory,
  });
  final Map<String, double> weights;
  final String dominant;
  final SIMemoryStore memory;
}

class SISyntheticIdentityGradient {
  const SISyntheticIdentityGradient();

  SIIdentityGradient calculate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final w = <String, double>{
      'guardian': instinct.safetyFirst ? .9 : .25,
      'builder':
          intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus'
          ? .8
          : .35,
      'analyst': intent.primary.label == 'insight_request' ? .85 : .3,
      'restorer': context.userState.fatigue >= .68 ? .8 : .25,
      'guide': .55,
    }.map((k, v) => MapEntry(k, siClamp01(v)));
    final dominant =
        (w.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content: 'identity_gradient|dominant=$dominant',
            timestamp: t,
            relevance: w[dominant]!,
            confidence: .72,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIIdentityGradient(
      weights: Map.unmodifiable(w),
      dominant: dominant,
      memory: next,
    );
  }
}
