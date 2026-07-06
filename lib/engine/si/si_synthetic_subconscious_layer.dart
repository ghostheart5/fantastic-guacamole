// lib/engine/si/si_synthetic_subconscious_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SISubconsciousSignal {
  const SISubconsciousSignal({
    required this.latentPressure,
    required this.hiddenNeed,
    required this.memory,
  });
  final double latentPressure;
  final String hiddenNeed;
  final SIMemoryStore memory;
}

class SISyntheticSubconsciousLayer {
  const SISyntheticSubconsciousLayer();

  SISubconsciousSignal infer({
    required SIContext context,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final l = context.input.latent;
    final pressure = siClamp01(
      l.frustration * .3 +
          l.confusion * .3 +
          l.hesitation * .25 +
          (1 - l.confidence) * .15,
    );
    final need = pressure >= .65
        ? 'stabilization'
        : l.confusion >= .55
        ? 'clarity'
        : l.excitement >= .65
        ? 'momentum_channel'
        : 'steady_support';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'subconscious|need=$need|pressure=${pressure.toStringAsFixed(2)}',
            timestamp: t,
            relevance: pressure,
            confidence: .66,
            emotionalWeight: pressure,
          ),
        )
        .dedupe()
        .decay(t);
    return SISubconsciousSignal(
      latentPressure: pressure,
      hiddenNeed: need,
      memory: next,
    );
  }
}
