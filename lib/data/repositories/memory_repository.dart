import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class MemoryRepository implements IMemoryRepository {
  MemoryRepository(this._store, this._scope, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The old global `memories_v1` key is deliberately not read, copied, or
  /// deleted. Its account ownership and consent provenance are ambiguous.
  static const String legacyGlobalKey = 'memories_v1';
  static const String _keyPrefix = 'governed_memories_v2';

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future<void>.value();

  String? get storageKey {
    final String? namespace = _scope.v2Namespace;
    if (!_scope.isWritable || namespace == null) return null;
    return '$_keyPrefix.$namespace';
  }

  @override
  List<MemoryEntity> getMemories() {
    final String? key = storageKey;
    final String? accountScopeId = _scope.v2Namespace;
    if (key == null || accountScopeId == null) {
      return const <MemoryEntity>[];
    }
    final String? raw = _store.load(key);
    if (raw == null || raw.trim().isEmpty) {
      return const <MemoryEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final DateTime now = _clock().toUtc();
      final List<MemoryEntity> decodedMemories = list
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntity.fromJson)
          .toList(growable: false);
      final List<MemoryEntity> memories = decodedMemories
          .where(
            (MemoryEntity memory) => _isValidOwnedActive(
              memory,
              accountScopeId: accountScopeId,
              now: now,
            ),
          )
          .toList(growable: false);
      if (memories.length != decodedMemories.length ||
          decodedMemories.length != list.length) {
        // Expiry is deletion authority granted when the memory was created.
        // Re-read inside the serialized cleanup so a concurrent consented save
        // can never be overwritten by a stale survivor list.
        unawaited(_serializeWrite(() => _purgeInvalidCurrent(key)));
      }
      memories.sort(
        (MemoryEntity a, MemoryEntity b) => b.date.compareTo(a.date),
      );
      return memories;
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode governed memories; returning empty result.',
        error,
        stackTrace,
      );
      return const <MemoryEntity>[];
    }
  }

  @override
  List<MemoryEntity> getMemoriesForSurface(MemorySurface surface) {
    final String? accountScopeId = _scope.v2Namespace;
    if (accountScopeId == null || surface == MemorySurface.siConsole) {
      return const <MemoryEntity>[];
    }
    final DateTime now = _clock().toUtc();
    return getMemories()
        .where(
          (MemoryEntity memory) => memory.canBeRetrieved(
            requestingAccountScopeId: accountScopeId,
            requestingSurface: surface,
            now: now,
          ),
        )
        .toList(growable: false);
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
  Future<void> saveMemory(MemoryEntity memory) async {
    _ensureWritable();
    _validateOwned(memory);
    await _serializeWrite(() async {
      final List<MemoryEntity> existing = getMemories().toList(growable: true);
      final int index = existing.indexWhere(
        (MemoryEntity item) => item.id == memory.id,
      );
      if (index >= 0) {
        existing[index] = memory;
      } else {
        existing.insert(0, memory);
      }
      await _persistValidated(existing);
    });
  }

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {
    _ensureWritable();
    final List<MemoryEntity> snapshot = List<MemoryEntity>.unmodifiable(
      memories,
    );
    for (final MemoryEntity memory in snapshot) {
      _validateOwned(memory);
    }
    await _serializeWrite(() => _persistValidated(snapshot));
  }

  Future<void> _persistValidated(List<MemoryEntity> memories) async {
    final String key = _ensureWritable();
    final DateTime now = _clock().toUtc();
    final List<MemoryEntity> active = memories
        .where((MemoryEntity memory) => !memory.isExpiredAt(now))
        .toList(growable: false);
    await _store.save(
      key,
      jsonEncode(active.map((MemoryEntity memory) => memory.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteMemory(String id) async {
    _ensureWritable();
    await _serializeWrite(() async {
      final List<MemoryEntity> next = getMemories()
          .where((MemoryEntity memory) => memory.id != id)
          .toList(growable: false);
      await _persistValidated(next);
    });
  }

  @override
  Future<void> deleteAllMemories() async {
    final String key = _ensureWritable();
    await _serializeWrite(() => _store.delete(key));
  }

  String _ensureWritable() {
    final String? key = storageKey;
    if (key == null) {
      throw StateError(
        'Governed memory storage is unavailable without a verified authenticated account scope.',
      );
    }
    return key;
  }

  void _validateOwned(MemoryEntity memory) {
    memory.validateForDurableStorage();
    if (memory.accountScopeId != _scope.v2Namespace) {
      throw StateError('Memory does not belong to this account scope.');
    }
  }

  bool _isValidOwnedActive(
    MemoryEntity memory, {
    required String accountScopeId,
    required DateTime now,
  }) {
    try {
      memory.validateForDurableStorage();
      return memory.accountScopeId == accountScopeId &&
          !memory.isExpiredAt(now);
    } on Object {
      return false;
    }
  }

  Future<void> _purgeInvalidCurrent(String key) async {
    try {
      final String? raw = _store.load(key);
      if (raw == null || raw.trim().isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;
      final String accountScopeId = _scope.v2Namespace!;
      final DateTime now = _clock().toUtc();
      final List<MemoryEntity> decodedMemories = decoded
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntity.fromJson)
          .toList(growable: false);
      final List<MemoryEntity> survivors = decodedMemories
          .where(
            (MemoryEntity memory) => _isValidOwnedActive(
              memory,
              accountScopeId: accountScopeId,
              now: now,
            ),
          )
          .toList(growable: false);
      if (survivors.length == decoded.length &&
          decodedMemories.length == decoded.length) {
        return;
      }
      await _store.save(
        key,
        jsonEncode(
          survivors.map((MemoryEntity memory) => memory.toJson()).toList(),
        ),
      );
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'MemoryExpiryCleanup',
        'Failed to remove expired governed memory records.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _serializeWrite(Future<void> Function() action) {
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }
}
