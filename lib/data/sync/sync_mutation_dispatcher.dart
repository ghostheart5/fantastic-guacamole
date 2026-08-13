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
  bool _cancelled = false;
  Future<void> _operationTail = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _operationTail.catchError((Object _) {});
  }

  void dispose() {
    _cancelled = true;
  }

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
  }) {
    final Future<void> previous = _operationTail.catchError((Object _) {});
    late final Future<bool> operation;
    operation = previous.then<bool>((_) async {
      final String? userId = _userId;
      if (userId == null || userId.trim().isEmpty) {
        return false;
      }
      if (!_isCurrentSession(userId)) {
        return false;
      }

      final DateTime now = DateTime.now().toUtc();
      final SyncOperation queued = SyncOperation(
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
      if (!_isCurrentSession(userId)) {
        return false;
      }
      final List<SyncOperation> filtered = current
          .where(
            (SyncOperation item) =>
                !(item.tableName == tableName &&
                    item.recordId == recordId &&
                    item.userId == userId &&
                    item.operationType == operationType),
          )
          .toList(growable: true);
      filtered.add(queued);
      await _queueStore.overwrite(filtered);
      return _isCurrentSession(userId);
    });
    _operationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  bool _isCurrentSession(String expectedUserId) {
    final sb.SupabaseClient? client = _supabaseClient;
    return !_cancelled &&
        (client == null || client.auth.currentUser?.id == expectedUserId);
  }
}
