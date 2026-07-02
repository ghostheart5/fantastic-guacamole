class MemoryFabric {
  const MemoryFabric({
    required this.nodes,
    required this.edges,
    required this.clusters,
    required this.reinforcementSignal,
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final List<String> clusters;
  final double reinforcementSignal;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nodes': nodes,
      'edges': edges,
      'clusters': clusters,
      'reinforcement_signal': reinforcementSignal,
    };
  }
}

class SyntheticMemoryFabric {
  const SyntheticMemoryFabric();

  MemoryFabric weave({
    required List<String> history,
    required String mood,
    required String intent,
  }) {
    final List<Map<String, dynamic>> nodes = history
        .take(8)
        .map(
          (String h) => <String, dynamic>{
            'content': h,
            'emotional_weight': mood == 'stressed' ? 0.75 : 0.45,
            'temporal_weight': 0.6,
          },
        )
        .toList();

    final List<Map<String, dynamic>> edges = <Map<String, dynamic>>[
      if (nodes.length >= 2)
        <String, dynamic>{
          'from': 0,
          'to': 1,
          'relation': 'sequence',
          'weight': 0.68,
        },
      if (intent == 'start_focus')
        <String, dynamic>{
          'from': 0,
          'to': 0,
          'relation': 'focus_reinforcement',
          'weight': 0.8,
        },
    ];

    return MemoryFabric(
      nodes: nodes,
      edges: edges,
      clusters: <String>[
        if (history.any((String h) => h.toLowerCase().contains('focus')))
          'focus_cluster',
        if (history.any((String h) => h.toLowerCase().contains('reflect')))
          'reflection_cluster',
      ],
      reinforcementSignal: (0.45 + (nodes.length * 0.05)).clamp(0.0, 1.0),
    );
  }
}
