// lib/engine/si/si_synthetic_consciousness_lattice.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SILatticeNode {
  const SILatticeNode(this.id, this.weight);
  final String id;
  final double weight;
}

class SILattice {
  const SILattice({
    required this.nodes,
    required this.density,
    required this.memory,
  });
  final List<SILatticeNode> nodes;
  final double density;
  final SIMemoryStore memory;
}

class SISyntheticConsciousnessLattice {
  const SISyntheticConsciousnessLattice();

  SILattice build({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final nodes = <SILatticeNode>[
      SILatticeNode(
        'intent:${intent.primary.label}',
        siClamp01(intent.confidence),
      ),
      SILatticeNode(
        'emotion:${context.userState.emotion}',
        siClamp01(
          (context.userState.stress + context.userState.engagement) / 2,
        ),
      ),
      SILatticeNode(
        'instinct:${instinct.primaryInstinct}',
        instinct.safetyFirst ? .9 : .55,
      ),
    ];
    final density = siClamp01(
      nodes.fold<double>(0, (s, n) => s + n.weight) / nodes.length,
    );
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'consciousness_lattice|nodes=${nodes.length}|density=${density.toStringAsFixed(2)}',
            timestamp: t,
            relevance: density,
            confidence: .68,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SILattice(
      nodes: List.unmodifiable(nodes),
      density: density,
      memory: next,
    );
  }
}
