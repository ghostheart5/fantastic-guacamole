import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_edge_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';

class AddFlowmapEdge {
  const AddFlowmapEdge(this._repository);

  final FlowmapRepository _repository;

  Future<void> call(FlowmapEdgeEntity edge) {
    return _repository.addEdge(edge);
  }
}
