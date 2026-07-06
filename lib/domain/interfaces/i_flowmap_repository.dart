import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';

abstract class IFlowmapRepository {
  Future<List<FlowmapNode>> getNodes();
  Future<void> saveNodes(List<FlowmapNode> nodes);
  Future<void> saveNode(FlowmapNode node);
  Future<void> deleteNode(String id);
}
