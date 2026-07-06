import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';

class UpdateFlowmapNode {
  const UpdateFlowmapNode(this._repository);

  final IFlowmapRepository _repository;

  Future<void> call(FlowmapNode node) => _repository.saveNode(node);
}
