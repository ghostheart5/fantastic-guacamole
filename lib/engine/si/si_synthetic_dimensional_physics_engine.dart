// lib/engine/si/si_synthetic_dimensional_physics_engine.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIDimensionalVector {
  const SIDimensionalVector({
    required this.values,
    required this.dominant,
    required this.guidance,
    required this.memory,
  });
  final Map<String, double> values;
  final String dominant;
  final String guidance;
  final SIMemoryStore memory;
}

class SISyntheticDimensionalPhysicsEngine {
  const SISyntheticDimensionalPhysicsEngine();

  SIDimensionalVector compute({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final v = <String, double>{
      'clarity': intent.confidence,
      'load': context.userState.cognitiveLoad,
      'stress': context.userState.stress,
      'momentum': context.userState.motivation,
      'safety': instinct.safetyFirst ? .9 : .55,
    }.map((k, v) => MapEntry(k, siClamp01(v)));
    final dominant =
        (v.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'dimensional_physics|dominant=$dominant',
            timestamp: t,
            relevance: v[dominant]!,
            confidence: .7,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIDimensionalVector(
      values: Map.unmodifiable(v),
      dominant: dominant,
      guidance: dominant == 'load' || dominant == 'stress'
          ? 'compress_and_stabilize'
          : 'act_with_clarity',
      memory: next,
    );
  }
}
