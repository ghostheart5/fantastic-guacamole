import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class MemoryRepository implements IMemoryRepository {
  MemoryRepository(this._store, {required this.storageScope});

  static const String legacyStorageKey = 'memories_v1';
  static const String _v2KeyPrefix = 'memories_v2';

  final SharedPrefsStore _store;
  final AccountStorageScope storageScope;

  String get _key {
    final String? namespace = storageScope.v2Namespace;
    if (!storageScope.isAuthenticated || namespace == null) {
      throw StateError('Memory persistence is unavailable outside a safe authenticated scope.');
    }
    return '$_v2KeyPrefix.$namespace';
  }

  static String canonicalStorageKeyForScope(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError('Memory persistence is unavailable outside a safe authenticated scope.');
    }
    return '$_v2KeyPrefix.$namespace';
  }

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
    } on Object catch (error) {
      throw StorageException('Memory storage is corrupted: $error');
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
