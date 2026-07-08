import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';

class ClearFlowmap {
  const ClearFlowmap(this._repository);

  final FlowmapRepository _repository;

  Future<void> call() {
    return _repository.clearFlowmap();
  }
}
