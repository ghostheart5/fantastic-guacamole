import 'package:fantastic_guacamole/features/flowmap/models/flowmap_node.dart';
import 'package:fantastic_guacamole/features/flowmap/repositories/flowmap_repository.dart';

class FlowmapService {
  FlowmapService(this._repository);

  final FlowmapRepository _repository;

  Future<List<FlowmapNode>> getNodes() => _repository.getNodes();

  Future<void> saveNode(FlowmapNode node) => _repository.saveNode(node);

  Future<void> deleteNode(String id) => _repository.deleteNode(id);
}
