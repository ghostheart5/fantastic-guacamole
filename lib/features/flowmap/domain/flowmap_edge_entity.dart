class FlowmapEdgeEntity {
  const FlowmapEdgeEntity({required this.fromNodeId, required this.toNodeId});

  final String fromNodeId;
  final String toNodeId;

  String get id => '$fromNodeId->$toNodeId';
}
