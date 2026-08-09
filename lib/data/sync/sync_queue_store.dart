import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';

abstract class SyncQueueStoreContract {
  Future<List<SyncOperation>> readAll();
  Future<void> overwrite(List<SyncOperation> operations);
  Future<void> enqueue(SyncOperation operation);
  Future<void> removeById(String operationId);
  Future<void> update(SyncOperation updated);
}

class SyncQueueStore implements SyncQueueStoreContract {
  SyncQueueStore(this._storage);

  static const String storageKey = 'sync_queue_v1';

  final HiveStorage<String> _storage;

  @override
  Future<List<SyncOperation>> readAll() async {
    await _storage.open();
    final String? raw = _storage.get(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SyncOperation>[];
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <SyncOperation>[];
    }

    final List<SyncOperation> operations = <SyncOperation>[];
    for (final Object? entry in decoded) {
      if (entry is! Map) {
        Logger.warn('Skipping malformed sync queue entry: not an object.');
        continue;
      }
      try {
        operations.add(
          SyncOperation.fromJson(
            entry.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      } on FormatException catch (error) {
        Logger.warn('Skipping malformed sync queue entry: $error');
      }
    }
    return operations;
  }

  @override
  Future<void> overwrite(List<SyncOperation> operations) {
    return _storage.put(
      storageKey,
      jsonEncode(
        operations
            .map((SyncOperation operation) => operation.toJson())
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    final List<SyncOperation> current = await readAll();
    await overwrite(<SyncOperation>[...current, operation]);
  }

  @override
  Future<void> removeById(String operationId) async {
    final List<SyncOperation> current = await readAll();
    final List<SyncOperation> next = current
        .where(
          (SyncOperation operation) => operation.operationId != operationId,
        )
        .toList(growable: false);
    await overwrite(next);
  }

  @override
  Future<void> update(SyncOperation updated) async {
    final List<SyncOperation> current = await readAll();
    final List<SyncOperation> next = current
        .map(
          (SyncOperation operation) =>
              operation.operationId == updated.operationId
              ? updated
              : operation,
        )
        .toList(growable: false);
    await overwrite(next);
  }
}
