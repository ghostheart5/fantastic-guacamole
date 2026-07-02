class IdentityMesh {
  const IdentityMesh({
    required this.nodes,
    required this.edges,
    required this.activeCluster,
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final List<String> activeCluster;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nodes': nodes,
      'edges': edges,
      'active_cluster': activeCluster,
    };
  }
}

class SyntheticMultiverseIdentityMesh {
  const SyntheticMultiverseIdentityMesh();

  IdentityMesh build({required String mood, required String intent}) {
    final List<Map<String, dynamic>> nodes = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'mentor',
        'traits': <String>['guidance', 'clarity'],
      },
      <String, dynamic>{
        'id': 'guardian',
        'traits': <String>['safety', 'stability'],
      },
      <String, dynamic>{
        'id': 'strategist',
        'traits': <String>['planning', 'priority'],
      },
      <String, dynamic>{
        'id': 'creator',
        'traits': <String>['novelty', 'imagination'],
      },
    ];
    final List<Map<String, dynamic>> edges = <Map<String, dynamic>>[
      <String, dynamic>{'from': 'mentor', 'to': 'strategist', 'weight': 0.72},
      <String, dynamic>{'from': 'guardian', 'to': 'mentor', 'weight': 0.68},
      <String, dynamic>{'from': 'creator', 'to': 'strategist', 'weight': 0.55},
    ];

    final List<String> active = <String>[
      if (mood == 'stressed') 'guardian',
      if (intent == 'start_focus') 'strategist',
      if (intent == 'insight_request') 'mentor',
      if (intent.contains('idea')) 'creator',
    ];
    return IdentityMesh(
      nodes: nodes,
      edges: edges,
      activeCluster: active.isEmpty ? <String>['mentor'] : active,
    );
  }
}
