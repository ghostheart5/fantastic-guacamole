import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class GetMemories {
  const GetMemories(this._repository);

  final IMemoryRepository _repository;

  List<MemoryEntity> call() => _repository.getMemories();

  PagedResult<MemoryEntity> page({String? cursor, int limit = 50}) {
    final List<MemoryEntity> memories = _repository.getMemories();
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : memories.indexWhere((MemoryEntity memory) => memory.id == cursor) + 1;
    if (startIndex >= memories.length) {
      return const PagedResult<MemoryEntity>(items: <MemoryEntity>[], nextCursor: null);
    }
    final List<MemoryEntity> page = memories
        .skip(startIndex)
        .take(safeLimit)
        .toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < memories.length && page.isNotEmpty ? page.last.id : null;
    return PagedResult<MemoryEntity>(items: page, nextCursor: nextCursor);
  }
}
