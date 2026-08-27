import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Memories
///
/// Bound to MemoryRepository.
abstract class IMemoryRepository {
  List<MemoryEntity> getMemories();

  /// Returns only consented, unexpired memories created by this exact surface.
  List<MemoryEntity> getMemoriesForSurface(MemorySurface surface) {
    return getMemories()
        .where((MemoryEntity memory) => memory.sourceSurface == surface)
        .toList(growable: false);
  }

  Future<void> saveMemory(MemoryEntity memory);
  Future<void> saveMemories(List<MemoryEntity> memories);
  Future<void> deleteMemory(String id);
  Future<void> deleteAllMemories() async {
    for (final MemoryEntity memory in getMemories()) {
      await deleteMemory(memory.id);
    }
  }
}
