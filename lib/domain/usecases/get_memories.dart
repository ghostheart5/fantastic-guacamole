import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';

class GetMemories {
  const GetMemories(this._repository);

  final IMemoryRepository _repository;

  List<MemoryEntity> call() => _repository.getMemories();
}
