import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';

abstract class IMemoryRepository {
  List<MemoryEntity> getMemories();

  Future<void> saveMemory(MemoryEntity memory);
  Future<void> saveMemories(List<MemoryEntity> memories);
  Future<void> deleteMemory(String id);
}
