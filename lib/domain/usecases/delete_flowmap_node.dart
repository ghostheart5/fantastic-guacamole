import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';

class DeleteFlowmapNode {
  const DeleteFlowmapNode(this._repository);

  final IFlowmapRepository _repository;

  Future<void> call(String id) => _repository.deleteNode(id);
}
