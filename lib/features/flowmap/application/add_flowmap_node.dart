import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_node_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';

class AddFlowmapNode {
  const AddFlowmapNode(this._repository);

  final FlowmapRepository _repository;

  Future<void> call(FlowmapNodeEntity node) {
    return _repository.addNode(node);
  }
}
