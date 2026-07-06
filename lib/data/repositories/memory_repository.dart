import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';

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
      return list
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <MemoryEntity>[];
    }
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
