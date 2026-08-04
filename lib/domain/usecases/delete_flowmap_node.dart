import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Flowmap
///
/// Resolved by flowmapProvider. Blank-id guarded.
class DeleteFlowmapNode {
  const DeleteFlowmapNode(this._repository);

  final IFlowmapRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteNode(InputGuard.id(id, 'id'));
}
