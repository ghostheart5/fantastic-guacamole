import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_edge_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_graph_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_node_entity.dart';

abstract class FlowmapRepository {
  Future<FlowmapGraphEntity> getFlowmap();
  Future<void> saveFlowmap(FlowmapGraphEntity graph);
  Future<void> clearFlowmap();
  Future<void> addNode(FlowmapNodeEntity node);
  Future<void> addEdge(FlowmapEdgeEntity edge);
}
