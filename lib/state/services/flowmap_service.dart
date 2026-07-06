import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';

class FlowmapService {
  FlowmapService(this._repository);

  final IFlowmapRepository _repository;

  Future<List<FlowmapNode>> getNodes() => _repository.getNodes();

  Future<void> saveNode(FlowmapNode node) => _repository.saveNode(node);

  Future<void> deleteNode(String id) => _repository.deleteNode(id);
}
