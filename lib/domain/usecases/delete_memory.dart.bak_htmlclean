import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';

class DeleteMemory {
  const DeleteMemory(this._repository);

  final IMemoryRepository _repository;

  Future<void> call(String id) => _repository.deleteMemory(id);
}
