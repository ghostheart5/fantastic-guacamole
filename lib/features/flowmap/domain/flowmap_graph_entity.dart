import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_edge_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_node_entity.dart';

class FlowmapGraphEntity {
  const FlowmapGraphEntity({
    this.nodes = const <FlowmapNodeEntity>[],
    this.edges = const <FlowmapEdgeEntity>[],
  });

  final List<FlowmapNodeEntity> nodes;
  final List<FlowmapEdgeEntity> edges;

  const FlowmapGraphEntity.empty()
    : nodes = const <FlowmapNodeEntity>[],
      edges = const <FlowmapEdgeEntity>[];
}
