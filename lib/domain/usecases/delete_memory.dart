import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Memories
///
/// Resolved by memoriesProvider. Blank-id guarded.
class DeleteMemory {
  const DeleteMemory(this._repository);

  final IMemoryRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteMemory(InputGuard.id(id, 'id'));
}
