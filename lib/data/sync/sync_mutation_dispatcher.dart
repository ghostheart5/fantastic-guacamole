import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SyncMutationDispatcher {
  SyncMutationDispatcher({
    required this._queueStore,
    required this._userId,
    this._supabaseClient,
  });

  final SyncQueueStoreContract _queueStore;
  // Retained as part of the existing construction boundary; PRE-01 does not
  // alter client-based dispatch behavior.
  // ignore: unused_field
  final sb.SupabaseClient? _supabaseClient;
  final String? _userId;

  Future<bool> enqueueUpsert({
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) {
    return _enqueue(
      tableName: tableName,
      recordId: recordId,
      operationType: SyncOperationType.update,
      payload: payload,
    );
  }

  Future<bool> enqueueDelete({
    required String tableName,
    required String recordId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return _enqueue(
      tableName: tableName,
      recordId: recordId,
      operationType: SyncOperationType.delete,
      payload: payload,
    );
  }

  Future<bool> _enqueue({
    required String tableName,
    required String recordId,
    required SyncOperationType operationType,
    required Map<String, dynamic> payload,
  }) async {
    final String? userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return false;
    }

    final DateTime now = DateTime.now().toUtc();
    final SyncOperation operation = SyncOperation(
      operationId:
          '${now.microsecondsSinceEpoch}_${tableName}_${operationType.name}_$recordId',
      tableName: tableName,
      recordId: recordId,
      operationType: operationType,
      payload: <String, dynamic>{...payload, 'user_id': userId},
      userId: userId,
      createdAtUtc: now,
      retryCount: 0,
      nextRetryAtUtc: null,
      lastError: null,
    );

    final List<SyncOperation> current = await _queueStore.readAll();
    final List<SyncOperation> filtered = current
        .where(
          (SyncOperation item) =>
              !(item.tableName == tableName &&
                  item.recordId == recordId &&
                  item.userId == userId &&
                  item.operationType == operationType),
        )
        .toList(growable: true);
    filtered.add(operation);
    await _queueStore.overwrite(filtered);
    return true;
  }
}
