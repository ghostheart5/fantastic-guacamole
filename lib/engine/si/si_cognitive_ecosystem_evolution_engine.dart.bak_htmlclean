// lib/engine/si/si_cognitive_ecosystem_evolution_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';

class EcosystemEvolutionConfig {
  const EcosystemEvolutionConfig({
    this.nodeDecayPerDay = 0.035,
    this.edgeDecayPerDay = 0.045,
    this.minimumNodeWeight = 0.08,
    this.minimumEdgeWeight = 0.06,
  });

  final double nodeDecayPerDay;
  final double edgeDecayPerDay;
  final double minimumNodeWeight;
  final double minimumEdgeWeight;
}

class EcosystemEvolutionResult {
  const EcosystemEvolutionResult({
    required this.state,
    required this.memory,
    required this.removedNodes,
    required this.removedEdges,
    required this.summary,
  });

  final SIEcosystemState state;
  final SIMemoryStore memory;
  final int removedNodes;
  final int removedEdges;
  final String summary;
}

class SICognitiveEcosystemEvolutionEngine {
  const SICognitiveEcosystemEvolutionEngine({
    this.config = const EcosystemEvolutionConfig(),
  });

  final EcosystemEvolutionConfig config;

  EcosystemEvolutionResult evolve({
    required SIEcosystemState state,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    final Map<String, EcosystemNode> nodes = <String, EcosystemNode>{};
    int removedNodes = 0;

    for (final EcosystemNode node in state.nodes.values) {
      final int ageDays = timestamp.difference(node.lastSeen).inDays;
      final double decay = siClamp01(
        ageDays * config.nodeDecayPerDay,
        fallback: 0,
      );
      final EcosystemNode next = node.decay(timestamp, decay);

      if (next.weight >= config.minimumNodeWeight) {
        nodes[next.id] = next;
      } else {
        removedNodes++;
      }
    }

    final Map<String, EcosystemEdge> edges = <String, EcosystemEdge>{};
    int removedEdges = 0;

    for (final EcosystemEdge edge in state.edges.values) {
      final int ageDays = timestamp.difference(edge.lastSeen).inDays;
      final double decay = siClamp01(
        ageDays * config.edgeDecayPerDay,
        fallback: 0,
      );
      final EcosystemEdge next = edge.decay(timestamp, decay);

      if (next.weight >= config.minimumEdgeWeight &&
          nodes.containsKey(next.from) &&
          nodes.containsKey(next.to)) {
        edges[next.id] = next;
      } else {
        removedEdges++;
      }
    }

    final SIEcosystemState evolved = SIEcosystemState(
      nodes: Map<String, EcosystemNode>.unmodifiable(nodes),
      edges: Map<String, EcosystemEdge>.unmodifiable(edges),
      updatedAt: timestamp,
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'ecosystem_evolution|nodes=${nodes.length}|edges=${edges.length}|removed_nodes=$removedNodes|removed_edges=$removedEdges',
            timestamp: timestamp,
            relevance: nodes.isEmpty ? 0.25 : 0.65,
            confidence: 0.75,
            recency: 1.0,
            emotionalWeight: 0.35,
            reinforcement: removedNodes == 0 && removedEdges == 0 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return EcosystemEvolutionResult(
      state: evolved,
      memory: nextMemory,
      removedNodes: removedNodes,
      removedEdges: removedEdges,
      summary:
          'Ecosystem evolved: ${nodes.length} nodes, ${edges.length} edges.',
    );
  }
}
