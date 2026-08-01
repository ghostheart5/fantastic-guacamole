import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryQueueStore implements SyncQueueStoreContract {
  final List<SyncOperation> _items;

  _InMemoryQueueStore([List<SyncOperation> seed = const <SyncOperation>[]])
    : _items = List<SyncOperation>.from(seed);

  @override
  Future<void> enqueue(SyncOperation operation) async {
    _items.add(operation);
  }

  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    _items
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async {
    return List<SyncOperation>.from(_items);
  }

  @override
  Future<void> removeById(String operationId) async {
    _items.removeWhere((SyncOperation item) => item.operationId == operationId);
  }

  @override
  Future<void> update(SyncOperation updated) async {
    final int index = _items.indexWhere(
      (SyncOperation item) => item.operationId == updated.operationId,
    );
    if (index == -1) {
      return;
    }
    _items[index] = updated;
  }
}

SyncOperation _op(String id) {
  return SyncOperation(
    operationId: id,
    tableName: 'tasks',
    recordId: 'record_$id',
    operationType: SyncOperationType.update,
    payload: const <String, dynamic>{'title': 'x'},
    userId: 'user_1',
    createdAtUtc: DateTime.utc(2026, 1, 1),
    retryCount: 0,
    nextRetryAtUtc: null,
    lastError: null,
  );
}

void main() {
  test('sync operation encode/decode roundtrip works', () {
    final SyncOperation original = _op('1');
    final SyncOperation decoded = SyncOperation.decode(original.encode());

    expect(decoded.operationId, original.operationId);
    expect(decoded.tableName, original.tableName);
    expect(decoded.recordId, original.recordId);
    expect(decoded.operationType, original.operationType);
    expect(decoded.payload, original.payload);
    expect(decoded.userId, original.userId);
  });

  test('runner removes successful operation', () async {
    final _InMemoryQueueStore queue = _InMemoryQueueStore(<SyncOperation>[
      _op('1'),
    ]);

    final SyncRunner runner = SyncRunner(
      queueStore: queue,
      applyFn: (SyncOperation operation) async => SyncApplyResult.success(),
      now: () => DateTime.utc(2026, 1, 1, 0, 0, 0),
    );

    await runner.runOnce();

    final List<SyncOperation> remaining = await queue.readAll();
    expect(remaining, isEmpty);
  });

  test('runner updates retry metadata on retryable failure', () async {
    final _InMemoryQueueStore queue = _InMemoryQueueStore(<SyncOperation>[
      _op('2'),
    ]);

    final SyncRunner runner = SyncRunner(
      queueStore: queue,
      applyFn: (SyncOperation operation) async {
        return SyncApplyResult.retryable('network down');
      },
      now: () => DateTime.utc(2026, 1, 1, 0, 0, 0),
    );

    await runner.runOnce();

    final List<SyncOperation> remaining = await queue.readAll();
    expect(remaining.length, 1);
    expect(remaining.first.retryCount, 1);
    expect(remaining.first.lastError, 'network down');
    expect(remaining.first.nextRetryAtUtc, isNotNull);
  });
}
