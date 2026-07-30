// lib/engine/si/si_synthetic_archetype_fusion_system.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_archetype_system.dart';

class SIArchetypeFusion {
  const SIArchetypeFusion({
    required this.primary,
    required this.secondary,
    required this.blend,
    required this.memory,
  });
  final SIArchetypeState primary;
  final SIArchetypeState? secondary;
  final double blend;
  final SIMemoryStore memory;
}

class SISyntheticArchetypeFusionSystem {
  const SISyntheticArchetypeFusionSystem();

  SIArchetypeFusion fuse({
    required List<SIArchetypeState> archetypes,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final sorted = archetypes.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final primary = sorted.isEmpty
        ? SIArchetypeState(
            name: 'guide',
            symbol: 'lantern',
            weight: .5,
            guidance: 'make_next_step_clear',
            memory: memory,
          )
        : sorted.first;
    final secondary = sorted.length > 1 ? sorted[1] : null;
    final blend = siClamp01(
      (primary.weight + (secondary?.weight ?? primary.weight)) / 2,
    );
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'archetype_fusion|${primary.name}|${secondary?.name ?? 'none'}|blend=${blend.toStringAsFixed(2)}',
            timestamp: t,
            relevance: blend,
            confidence: .7,
            emotionalWeight: .35,
            reinforcement: blend >= .7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);
    return SIArchetypeFusion(
      primary: primary,
      secondary: secondary,
      blend: blend,
      memory: next,
    );
  }
}
