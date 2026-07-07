import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_graph_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';

class GetFlowmap {
  const GetFlowmap(this._repository);

  final FlowmapRepository _repository;

  Future<FlowmapGraphEntity> call() {
    return _repository.getFlowmap();
  }
}
