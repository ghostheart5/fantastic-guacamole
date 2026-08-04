import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Memories
///
/// Registered as saveMemoriesUseCaseProvider; bulk replace for import/restore.
/// Empty-batch guarded.
/// Replaces the whole stored memory collection. Pass `allowClear: true` to
/// clear it deliberately; an empty list is otherwise rejected as an accident.
class SaveMemories {
  const SaveMemories(this._repository);

  final IMemoryRepository _repository;

  Future<void> call(List<MemoryEntity> memories, {bool allowClear = false}) =>
      _repository.saveMemories(
        InputGuard.batch(memories, 'memories', allowClear: allowClear),
      );
}
