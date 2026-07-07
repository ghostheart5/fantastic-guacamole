import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';

class SaveMemories {
  const SaveMemories(this._repository);

  final IMemoryRepository _repository;

  Future<void> call(List<MemoryEntity> memories) =>
      _repository.saveMemories(memories);
}
