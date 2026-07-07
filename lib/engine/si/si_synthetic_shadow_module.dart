// lib/engine/si/si_synthetic_shadow_module.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIShadowSignal {
  const SIShadowSignal({
    required this.resistance,
    required this.trigger,
    required this.reframe,
    required this.memory,
  });
  final double resistance;
  final String trigger;
  final String reframe;
  final SIMemoryStore memory;
}

class SISyntheticShadowModule {
  const SISyntheticShadowModule();

  SIShadowSignal detect({
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final resistance = siClamp01(
      context.userState.frustration * .35 +
          context.userState.cognitiveLoad * .35 +
          context.userState.fatigue * .3,
    );
    final trigger = resistance >= .65 ? 'resistance_high' : 'resistance_low';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'shadow|$trigger|resistance=${resistance.toStringAsFixed(2)}',
            timestamp: t,
            relevance: resistance,
            confidence: .66,
            emotionalWeight: resistance,
          ),
        )
        .dedupe()
        .decay(t);
    return SIShadowSignal(
      resistance: resistance,
      trigger: trigger,
      reframe: resistance >= .65
          ? 'Shrink the task until it feels possible.'
          : 'Proceed with steady clarity.',
      memory: next,
    );
  }
}
