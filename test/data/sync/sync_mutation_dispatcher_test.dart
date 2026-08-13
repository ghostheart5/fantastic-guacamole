import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
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
    if (index != -1) {
      _items[index] = updated;
    }
  }
}

void main() {
  test('dispatcher does not enqueue without an explicit user id', () async {
    final _InMemoryQueueStore queue = _InMemoryQueueStore();
    final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
      queueStore: queue,
      userId: null,
    );

    final bool enqueued = await dispatcher.enqueueUpsert(
      tableName: 'tasks',
      recordId: 'a',
      payload: const <String, dynamic>{'title': 'x'},
    );

    expect(enqueued, isFalse);
    expect((await queue.readAll()).length, 0);
  });

  test('dispatcher de-duplicates same table/record/op for same user', () async {
    final _InMemoryQueueStore queue = _InMemoryQueueStore();
    final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
      queueStore: queue,
      userId: 'u1',
    );

    await dispatcher.enqueueUpsert(
      tableName: 'tasks',
      recordId: 'a',
      payload: const <String, dynamic>{'title': 'first'},
    );
    await dispatcher.enqueueUpsert(
      tableName: 'tasks',
      recordId: 'a',
      payload: const <String, dynamic>{'title': 'second'},
    );

    final List<SyncOperation> items = await queue.readAll();
    expect(items.length, 1);
    expect(items.first.payload['title'], 'second');
    expect(items.first.userId, 'u1');
    expect(items.first.payload['user_id'], 'u1');
  });

  test('dispatcher retains its captured user scope', () async {
    final _InMemoryQueueStore queue = _InMemoryQueueStore();
    final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
      queueStore: queue,
      userId: 'user-a',
    );

    await dispatcher.enqueueUpsert(
      tableName: 'tasks',
      recordId: 'a',
      payload: const <String, dynamic>{},
    );

    expect((await queue.readAll()).single.userId, 'user-a');
  });
}
