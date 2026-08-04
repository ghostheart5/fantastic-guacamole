import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Flowmap
///
/// Resolved by flowmapProvider. NOTE: class name GetFlowmap collides with
/// lib/features/flowmap/application/get_flowmap.dart.
class GetFlowmap {
  const GetFlowmap(this._repository);

  final IFlowmapRepository _repository;

  Future<List<FlowmapNode>> call() => _repository.getNodes();
}
