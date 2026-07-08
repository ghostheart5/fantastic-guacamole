import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class MemoryRepository implements IMemoryRepository {
  MemoryRepository(this._store);

  static const String _key = 'memories_v1';

  final SharedPrefsStore _store;

  @override
  List<MemoryEntity> getMemories() {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <MemoryEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<MemoryEntity> memories = list
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntity.fromJson)
          .toList(growable: false);
      memories.sort(
        (MemoryEntity a, MemoryEntity b) => b.date.compareTo(a.date),
      );
      return memories;
    } catch (_) {
      return const <MemoryEntity>[];
    }
  }

  PagedResult<MemoryEntity> getMemoriesPage({String? cursor, int limit = 50}) {
    final List<MemoryEntity> memories = getMemories();
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : memories.indexWhere((MemoryEntity memory) => memory.id == cursor) + 1;
    if (startIndex >= memories.length) {
      return const PagedResult<MemoryEntity>(
        items: <MemoryEntity>[],
        nextCursor: null,
      );
    }
    final List<MemoryEntity> page = memories
        .skip(startIndex)
        .take(safeLimit)
        .toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < memories.length && page.isNotEmpty
        ? page.last.id
        : null;
    return PagedResult<MemoryEntity>(items: page, nextCursor: nextCursor);
  }

  @override
  Future<void> saveMemory(MemoryEntity memory) {
    final List<MemoryEntity> existing = getMemories().toList(growable: true);
    final int index = existing.indexWhere(
      (MemoryEntity item) => item.id == memory.id,
    );
    if (index >= 0) {
      existing[index] = memory;
    } else {
      existing.insert(0, memory);
    }
    return saveMemories(existing);
  }

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) {
    return _store.save(
      _key,
      jsonEncode(memories.map((MemoryEntity m) => m.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteMemory(String id) {
    final List<MemoryEntity> next = getMemories()
        .where((MemoryEntity memory) => memory.id != id)
        .toList(growable: false);
    return saveMemories(next);
  }
}
