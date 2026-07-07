// lib/engine/si/si_cognitive_ecosystem_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

enum EcosystemNodeType { task, intent, mood, pattern, action, state }

class EcosystemNode {
  const EcosystemNode({
    required this.id,
    required this.type,
    required this.label,
    required this.weight,
    required this.lastSeen,
    this.hits = 1,
  });

  final String id;
  final EcosystemNodeType type;
  final String label;
  final double weight;
  final DateTime lastSeen;
  final int hits;

  EcosystemNode bump(DateTime now, double amount) {
    return EcosystemNode(
      id: id,
      type: type,
      label: label,
      weight: siClamp01(weight + amount),
      lastSeen: now,
      hits: hits + 1,
    );
  }

  EcosystemNode decay(DateTime now, double amount) {
    return EcosystemNode(
      id: id,
      type: type,
      label: label,
      weight: siClamp01(weight - amount),
      lastSeen: now,
      hits: hits,
    );
  }
}

class EcosystemEdge {
  const EcosystemEdge({
    required this.from,
    required this.to,
    required this.weight,
    required this.lastSeen,
    this.hits = 1,
  });

  final String from;
  final String to;
  final double weight;
  final DateTime lastSeen;
  final int hits;

  String get id => '$from->$to';

  EcosystemEdge bump(DateTime now, double amount) {
    return EcosystemEdge(
      from: from,
      to: to,
      weight: siClamp01(weight + amount),
      lastSeen: now,
      hits: hits + 1,
    );
  }

  EcosystemEdge decay(DateTime now, double amount) {
    return EcosystemEdge(
      from: from,
      to: to,
      weight: siClamp01(weight - amount),
      lastSeen: now,
      hits: hits,
    );
  }
}

class SIEcosystemState {
  const SIEcosystemState({
    this.nodes = const <String, EcosystemNode>{},
    this.edges = const <String, EcosystemEdge>{},
    this.updatedAt,
  });

  final Map<String, EcosystemNode> nodes;
  final Map<String, EcosystemEdge> edges;
  final DateTime? updatedAt;

  EcosystemNode? node(String id) => nodes[id];
}

class EcosystemUpdate {
  const EcosystemUpdate({
    required this.state,
    required this.memory,
    required this.focusNodes,
    required this.summary,
  });

  final SIEcosystemState state;
  final SIMemoryStore memory;
  final List<EcosystemNode> focusNodes;
  final String summary;
}

class SICognitiveEcosystemLayer {
  const SICognitiveEcosystemLayer();

  EcosystemUpdate observe({
    required SIEcosystemState current,
    required SIMemoryStore memory,
    required SIContext context,
    SIIntent? intent,
    SIDecision? decision,
    SIResponse? response,
    MicroPatternReport? patterns,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final Map<String, EcosystemNode> nodes = Map<String, EcosystemNode>.from(
      current.nodes,
    );
    final Map<String, EcosystemEdge> edges = Map<String, EcosystemEdge>.from(
      current.edges,
    );

    final String moodId = _nodeId(
      EcosystemNodeType.mood,
      context.userState.emotion,
    );
    _bumpNode(
      nodes,
      moodId,
      EcosystemNodeType.mood,
      context.userState.emotion,
      timestamp,
      0.08,
    );

    final String stateId = _nodeId(
      EcosystemNodeType.state,
      context.userState.stability,
    );
    _bumpNode(
      nodes,
      stateId,
      EcosystemNodeType.state,
      context.userState.stability,
      timestamp,
      0.06,
    );
    _bumpEdge(edges, moodId, stateId, timestamp, 0.05);

    if (intent != null) {
      final String intentId = _nodeId(
        EcosystemNodeType.intent,
        intent.primary.label,
      );
      _bumpNode(
        nodes,
        intentId,
        EcosystemNodeType.intent,
        intent.primary.label,
        timestamp,
        0.08,
      );
      _bumpEdge(edges, moodId, intentId, timestamp, 0.05);
    }

    if (decision != null) {
      final String actionId = _nodeId(
        EcosystemNodeType.action,
        decision.action,
      );
      _bumpNode(
        nodes,
        actionId,
        EcosystemNodeType.action,
        decision.action,
        timestamp,
        0.08,
      );
      _bumpEdge(edges, stateId, actionId, timestamp, 0.06);

      final String task = siClean(decision.task?.title);
      if (task.isNotEmpty) {
        final String taskId = _nodeId(EcosystemNodeType.task, task);
        _bumpNode(nodes, taskId, EcosystemNodeType.task, task, timestamp, 0.12);
        _bumpEdge(edges, actionId, taskId, timestamp, 0.07);
      }
    }

    if (patterns != null) {
      for (final MicroPattern pattern in patterns.patterns.take(6)) {
        final String patternId = _nodeId(
          EcosystemNodeType.pattern,
          pattern.type.name,
        );
        _bumpNode(
          nodes,
          patternId,
          EcosystemNodeType.pattern,
          pattern.label,
          timestamp,
          0.08 + pattern.strength * 0.08,
        );
        _bumpEdge(edges, stateId, patternId, timestamp, 0.05);
      }
    }

    final SIEcosystemState next = SIEcosystemState(
      nodes: Map<String, EcosystemNode>.unmodifiable(nodes),
      edges: Map<String, EcosystemEdge>.unmodifiable(edges),
      updatedAt: timestamp,
    );

    final List<EcosystemNode> focus = _focusNodes(next);

    SIMemoryStore updatedMemory = memory.pushRecord(
      MemoryTier.midTerm,
      MemoryRecord(
        content:
            'ecosystem|nodes=${nodes.length}|edges=${edges.length}|focus=${focus.map((e) => e.label).take(3).join(",")}',
        timestamp: timestamp,
        relevance: focus.isEmpty ? 0.45 : focus.first.weight,
        confidence: 0.7,
        recency: 1.0,
        emotionalWeight: siClamp01(context.userState.stress),
        reinforcement: 1,
      ),
    );

    updatedMemory = updatedMemory.dedupe().decay(timestamp);

    return EcosystemUpdate(
      state: next,
      memory: updatedMemory,
      focusNodes: List<EcosystemNode>.unmodifiable(focus),
      summary: focus.isEmpty
          ? 'Ecosystem initialized.'
          : 'Active ecosystem nodes: ${focus.map((EcosystemNode n) => n.label).take(3).join(', ')}.',
    );
  }

  void _bumpNode(
    Map<String, EcosystemNode> nodes,
    String id,
    EcosystemNodeType type,
    String label,
    DateTime now,
    double amount,
  ) {
    final EcosystemNode? existing = nodes[id];
    nodes[id] = existing == null
        ? EcosystemNode(
            id: id,
            type: type,
            label: label,
            weight: siClamp01(0.45 + amount),
            lastSeen: now,
          )
        : existing.bump(now, amount);
  }

  void _bumpEdge(
    Map<String, EcosystemEdge> edges,
    String from,
    String to,
    DateTime now,
    double amount,
  ) {
    final String id = '$from->$to';
    final EcosystemEdge? existing = edges[id];
    edges[id] = existing == null
        ? EcosystemEdge(
            from: from,
            to: to,
            weight: siClamp01(0.35 + amount),
            lastSeen: now,
          )
        : existing.bump(now, amount);
  }

  List<EcosystemNode> _focusNodes(SIEcosystemState state) {
    final List<EcosystemNode> out = state.nodes.values.toList()
      ..sort(
        (EcosystemNode a, EcosystemNode b) => b.weight.compareTo(a.weight),
      );
    return out.take(8).toList();
  }

  String _nodeId(EcosystemNodeType type, String value) {
    return '${type.name}:${siClean(value, fallback: 'unknown').toLowerCase()}';
  }
}
