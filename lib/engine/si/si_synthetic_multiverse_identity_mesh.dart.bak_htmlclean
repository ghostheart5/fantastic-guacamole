// lib/engine/si/si_synthetic_multiverse_identity_mesh.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_identity_gradient.dart';

class SIIdentityMesh {
  const SIIdentityMesh({
    required this.nodes,
    required this.center,
    required this.coherence,
    required this.memory,
  });
  final List<String> nodes;
  final String center;
  final double coherence;
  final SIMemoryStore memory;
}

class SISyntheticMultiverseIdentityMesh {
  const SISyntheticMultiverseIdentityMesh();

  SIIdentityMesh build({
    required SIIdentityGradient gradient,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final nodes = gradient.weights.entries
        .where((e) => e.value >= .35)
        .map((e) => e.key)
        .toList();
    final coherence = siClamp01(
      gradient.weights.values.reduce((a, b) => a + b) / gradient.weights.length,
    );
    final next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'identity_mesh|center=${gradient.dominant}|nodes=${nodes.join(",")}',
            timestamp: t,
            relevance: coherence,
            confidence: .7,
            emotionalWeight: .35,
          ),
        )
        .dedupe()
        .decay(t);
    return SIIdentityMesh(
      nodes: List.unmodifiable(nodes),
      center: gradient.dominant,
      coherence: coherence,
      memory: next,
    );
  }
}
