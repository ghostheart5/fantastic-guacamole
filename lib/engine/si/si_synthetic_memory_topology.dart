// lib/engine/si/si_synthetic_memory_topology.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum MemoryRelationType { causal, temporal, semantic, emotional }

class MemoryNode {
  const MemoryNode({
    required this.id,
    required this.label,
    required this.weight,
    required this.lastSeen,
  });

  final String id;
  final String label;
  final double weight;
  final DateTime lastSeen;

  MemoryNode bump(DateTime now, double amount) => MemoryNode(
    id: id,
    label: label,
    weight: siClamp01(weight + amount),
    lastSeen: now,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'weight': siClamp01(weight),
    'lastSeen': lastSeen.toIso8601String(),
  };

  static MemoryNode fromJson(Map<String, dynamic> json) => MemoryNode(
    id: siClean(json['id']?.toString(), fallback: 'node'),
    label: siClean(json['label']?.toString(), fallback: 'memory'),
    weight: siClamp01(json['weight'] as num?),
    lastSeen:
        DateTime.tryParse(json['lastSeen']?.toString() ?? '') ?? DateTime.now(),
  );
}

class MemoryEdge {
  const MemoryEdge({
    required this.from,
    required this.to,
    required this.type,
    required this.weight,
    required this.lastSeen,
    this.bidirectional = true,
  });

  final String from;
  final String to;
  final MemoryRelationType type;
  final double weight;
  final DateTime lastSeen;
  final bool bidirectional;

  String get id => '${type.name}:$from->$to';

  MemoryEdge bump(DateTime now, double amount) => MemoryEdge(
    from: from,
    to: to,
    type: type,
    weight: siClamp01(weight + amount),
    lastSeen: now,
    bidirectional: bidirectional,
  );

  MemoryEdge decay(DateTime now, double amount) => MemoryEdge(
    from: from,
    to: to,
    type: type,
    weight: siClamp01(weight - amount),
    lastSeen: now,
    bidirectional: bidirectional,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'from': from,
    'to': to,
    'type': type.name,
    'weight': siClamp01(weight),
    'lastSeen': lastSeen.toIso8601String(),
    'bidirectional': bidirectional,
  };

  static MemoryEdge fromJson(Map<String, dynamic> json) => MemoryEdge(
    from: siClean(json['from']?.toString(), fallback: 'from'),
    to: siClean(json['to']?.toString(), fallback: 'to'),
    type: MemoryRelationType.values.firstWhere(
      (MemoryRelationType t) => t.name == json['type'],
      orElse: () => MemoryRelationType.semantic,
    ),
    weight: siClamp01(json['weight'] as num?),
    lastSeen:
        DateTime.tryParse(json['lastSeen']?.toString() ?? '') ?? DateTime.now(),
    bidirectional: json['bidirectional'] != false,
  );
}

class MemoryTopology {
  const MemoryTopology({
    this.nodes = const <String, MemoryNode>{},
    this.edges = const <String, MemoryEdge>{},
  });

  final Map<String, MemoryNode> nodes;
  final Map<String, MemoryEdge> edges;

  List<MemoryNode> neighbors(String nodeId) {
    final Set<String> ids = <String>{};
    for (final MemoryEdge e in edges.values) {
      if (e.from == nodeId) ids.add(e.to);
      if (e.bidirectional && e.to == nodeId) ids.add(e.from);
    }
    return ids.map((String id) => nodes[id]).whereType<MemoryNode>().toList();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nodes': nodes.map(
      (String k, MemoryNode v) => MapEntry<String, dynamic>(k, v.toJson()),
    ),
    'edges': edges.map(
      (String k, MemoryEdge v) => MapEntry<String, dynamic>(k, v.toJson()),
    ),
  };

  static MemoryTopology fromJson(Map<String, dynamic> json) {
    final Map<String, MemoryNode> nodes = <String, MemoryNode>{};
    final Map<String, MemoryEdge> edges = <String, MemoryEdge>{};

    final Map<dynamic, dynamic> rawNodes =
        (json['nodes'] as Map<dynamic, dynamic>?) ?? const <String, dynamic>{};
    for (final MapEntry<dynamic, dynamic> e in rawNodes.entries) {
      final MemoryNode n = MemoryNode.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
      nodes[e.key.toString()] = n;
    }

    final Map<dynamic, dynamic> rawEdges =
        (json['edges'] as Map<dynamic, dynamic>?) ?? const <String, dynamic>{};
    for (final MapEntry<dynamic, dynamic> e in rawEdges.entries) {
      final MemoryEdge edge = MemoryEdge.fromJson(
        Map<String, dynamic>.from(e.value as Map),
      );
      edges[e.key.toString()] = edge;
    }

    return MemoryTopology(
      nodes: Map<String, MemoryNode>.unmodifiable(nodes),
      edges: Map<String, MemoryEdge>.unmodifiable(edges),
    );
  }
}

class MemoryTopologyUpdate {
  const MemoryTopologyUpdate({
    required this.topology,
    required this.memory,
    required this.summary,
  });

  final MemoryTopology topology;
  final SIMemoryStore memory;
  final String summary;
}

class SISyntheticMemoryTopology {
  const SISyntheticMemoryTopology();

  MemoryTopologyUpdate build({
    required MemoryTopology current,
    required SIMemoryStore memory,
    required SIContext context,
    SIDecision? decision,
    SIResponse? response,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final Map<String, MemoryNode> nodes = Map<String, MemoryNode>.from(
      current.nodes,
    );
    final Map<String, MemoryEdge> edges = Map<String, MemoryEdge>.from(
      current.edges,
    );

    final String mood = _id('mood', context.userState.emotion);
    final String action = _id('action', decision?.action ?? 'respond');
    final String text = _id(
      'message',
      _token(response?.message ?? decision?.reasoning ?? context.input.text),
    );

    _node(nodes, mood, context.userState.emotion, t, 0.08);
    _node(nodes, action, decision?.action ?? 'respond', t, 0.08);
    _node(nodes, text, text, t, 0.06);

    _edge(edges, mood, action, MemoryRelationType.causal, t, 0.07);
    _edge(edges, action, text, MemoryRelationType.semantic, t, 0.06);

    final String task = siClean(decision?.task?.title);
    if (task.isNotEmpty) {
      final String taskId = _id('task', task);
      _node(nodes, taskId, task, t, 0.12);
      _edge(edges, action, taskId, MemoryRelationType.temporal, t, 0.08);
    }

    final MemoryTopology topology = MemoryTopology(
      nodes: Map<String, MemoryNode>.unmodifiable(nodes),
      edges: Map<String, MemoryEdge>.unmodifiable(_decayed(edges, t)),
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'memory_topology|nodes=${topology.nodes.length}|edges=${topology.edges.length}',
            timestamp: t,
            relevance: siClamp01(topology.edges.length / 20),
            confidence: 0.72,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: 1,
          ),
        )
        .dedupe()
        .decay(t);

    return MemoryTopologyUpdate(
      topology: topology,
      memory: nextMemory,
      summary:
          'Topology updated with ${topology.nodes.length} nodes and ${topology.edges.length} edges.',
    );
  }

  void _node(
    Map<String, MemoryNode> nodes,
    String id,
    String label,
    DateTime now,
    double amount,
  ) {
    nodes[id] =
        nodes[id]?.bump(now, amount) ??
        MemoryNode(
          id: id,
          label: label,
          weight: siClamp01(0.4 + amount),
          lastSeen: now,
        );
  }

  void _edge(
    Map<String, MemoryEdge> edges,
    String from,
    String to,
    MemoryRelationType type,
    DateTime now,
    double amount,
  ) {
    final MemoryEdge edge = MemoryEdge(
      from: from,
      to: to,
      type: type,
      weight: siClamp01(0.35 + amount),
      lastSeen: now,
    );
    edges[edge.id] = edges[edge.id]?.bump(now, amount) ?? edge;
  }

  Map<String, MemoryEdge> _decayed(
    Map<String, MemoryEdge> edges,
    DateTime now,
  ) {
    final Map<String, MemoryEdge> out = <String, MemoryEdge>{};
    for (final MemoryEdge e in edges.values) {
      final double decay = siClamp01(
        now.difference(e.lastSeen).inDays * 0.03,
        fallback: 0,
      );
      final MemoryEdge next = e.decay(now, decay);
      if (next.weight >= 0.06) out[next.id] = next;
    }
    return out;
  }

  String _id(String type, String value) =>
      '$type:${siClean(value, fallback: 'unknown').toLowerCase()}';
  String _token(String value) =>
      siClean(value, fallback: 'memory').split(' ').take(4).join('_');
}
