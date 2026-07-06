// lib/engine/si/si_synthetic_culture_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SICultureProfile {
  const SICultureProfile({
    required this.mode,
    required this.norms,
    required this.alignment,
    required this.memory,
  });
  final String mode;
  final List<String> norms;
  final double alignment;
  final SIMemoryStore memory;
}

class SISyntheticCultureLayer {
  const SISyntheticCultureLayer();

  SICultureProfile evaluate({
    required SIContext context,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final mode = instinct.safetyFirst
        ? 'guardian_culture'
        : context.userState.motivation >= .7
        ? 'builder_culture'
        : 'steady_culture';
    final norms = <String>[
      'preserve_agency',
      'reduce_overwhelm',
      'one_next_action',
      'non_judgment',
    ];
    final alignment = siClamp01(
      (1 - context.userState.stress) * .3 +
          (1 - context.userState.cognitiveLoad) * .25 +
          (instinct.increaseClarity ? .25 : .1) +
          .2,
    );
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'synthetic_culture|$mode|alignment=${alignment.toStringAsFixed(2)}',
            timestamp: t,
            relevance: alignment,
            confidence: .72,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SICultureProfile(
      mode: mode,
      norms: List.unmodifiable(norms),
      alignment: alignment,
      memory: next,
    );
  }
}
