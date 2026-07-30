import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';

class SaveMemory {
  const SaveMemory(this._repository);

  final IMemoryRepository _repository;

  Future<void> call(MemoryEntity memory) => _repository.saveMemory(memory);
}
