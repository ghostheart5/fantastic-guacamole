class ConsciousnessLattice {
  const ConsciousnessLattice({
    required this.nodes,
    required this.edges,
    required this.layers,
    required this.clusters,
    required this.flows,
  });

  final List<String> nodes;
  final List<Map<String, dynamic>> edges;
  final List<String> layers;
  final List<String> clusters;
  final List<String> flows;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nodes': nodes,
      'edges': edges,
      'layers': layers,
      'clusters': clusters,
      'flows': flows,
    };
  }
}

class SyntheticConsciousnessLattice {
  const SyntheticConsciousnessLattice();

  ConsciousnessLattice build({required String phase, required String persona}) {
    final List<String> nodes = <String>[
      'emotion_module',
      'reasoning_module',
      'memory_module',
      'narrative_module',
      'persona_module',
    ];
    final List<Map<String, dynamic>> edges = <Map<String, dynamic>>[
      <String, dynamic>{
        'from': 'emotion_module',
        'to': 'reasoning_module',
        'w': 0.7,
      },
      <String, dynamic>{
        'from': 'memory_module',
        'to': 'narrative_module',
        'w': 0.75,
      },
      <String, dynamic>{
        'from': 'persona_module',
        'to': 'reasoning_module',
        'w': 0.68,
      },
    ];
    return ConsciousnessLattice(
      nodes: nodes,
      edges: edges,
      layers: <String>[
        'reactive',
        'contextual',
        'reflective',
        'synthetic',
        phase,
      ],
      clusters: <String>[persona, 'alignment_cluster', 'continuity_cluster'],
      flows: <String>[
        'emotion->reasoning',
        'memory->narrative',
        'persona->response',
      ],
    );
  }
}
