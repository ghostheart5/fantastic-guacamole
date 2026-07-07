// lib/engine/si/si_cognitive_cosmology_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class ConceptNode {
  const ConceptNode({
    required this.id,
    required this.label,
    required this.weight,
  });

  final String id;
  final String label;
  final double weight;
}

class ConceptRelation {
  const ConceptRelation({
    required this.from,
    required this.to,
    required this.relation,
    required this.strength,
  });

  final String from;
  final String to;
  final String relation;
  final double strength;
}

class CognitiveCosmology {
  const CognitiveCosmology({
    required this.nodes,
    required this.relations,
    required this.center,
    required this.systemSummary,
    required this.memory,
  });

  final List<ConceptNode> nodes;
  final List<ConceptRelation> relations;
  final String center;
  final String systemSummary;
  final SIMemoryStore memory;
}

class SICognitiveCosmologyEngine {
  const SICognitiveCosmologyEngine();

  CognitiveCosmology map({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<ConceptNode> nodes = <ConceptNode>[
      ConceptNode(
        id: 'intent',
        label: intent.primary.label,
        weight: intent.confidence,
      ),
      ConceptNode(
        id: 'emotion',
        label: context.userState.emotion,
        weight: _stateWeight(context),
      ),
      ConceptNode(
        id: 'instinct',
        label: instinct.primaryInstinct,
        weight: instinct.safetyFirst ? 0.9 : 0.55,
      ),
    ];

    for (final MicroPattern p
        in patterns?.patterns.take(4) ?? const <MicroPattern>[]) {
      nodes.add(
        ConceptNode(
          id: 'pattern:${p.type.name}',
          label: p.label,
          weight: p.strength,
        ),
      );
    }

    final List<ConceptNode> safeNodes =
        nodes
            .map(
              (ConceptNode n) => ConceptNode(
                id: n.id,
                label: n.label,
                weight: siClamp01(n.weight),
              ),
            )
            .toList()
          ..sort(
            (ConceptNode a, ConceptNode b) => b.weight.compareTo(a.weight),
          );

    final List<ConceptRelation> relations = _relations(safeNodes, instinct);
    final String center = safeNodes.isEmpty ? 'none' : safeNodes.first.label;
    final String summary = _summary(center, safeNodes, instinct);

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'cosmology|center=$center|nodes=${safeNodes.length}|relations=${relations.length}',
            timestamp: timestamp,
            relevance: safeNodes.isEmpty ? 0.35 : safeNodes.first.weight,
            confidence: 0.66,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: instinct.safetyFirst ? 0 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return CognitiveCosmology(
      nodes: List<ConceptNode>.unmodifiable(safeNodes),
      relations: List<ConceptRelation>.unmodifiable(relations),
      center: center,
      systemSummary: summary,
      memory: nextMemory,
    );
  }

  double _stateWeight(SIContext context) {
    final SIUserState u = context.userState;
    return siClamp01(
      (u.stress + u.cognitiveLoad + u.motivation + u.engagement) / 4,
    );
  }

  List<ConceptRelation> _relations(
    List<ConceptNode> nodes,
    InstinctGuidance instinct,
  ) {
    final List<ConceptRelation> out = <ConceptRelation>[];
    for (int i = 0; i < nodes.length - 1; i++) {
      out.add(
        ConceptRelation(
          from: nodes[i].id,
          to: nodes[i + 1].id,
          relation: instinct.safetyFirst ? 'constrains' : 'influences',
          strength: siClamp01((nodes[i].weight + nodes[i + 1].weight) / 2),
        ),
      );
    }
    return out;
  }

  String _summary(
    String center,
    List<ConceptNode> nodes,
    InstinctGuidance instinct,
  ) {
    if (instinct.safetyFirst) {
      return 'The system center is $center, but safety constrains output.';
    }
    return 'The strongest current concept is $center, shaped by ${nodes.take(3).map((ConceptNode n) => n.label).join(', ')}.';
  }
}
