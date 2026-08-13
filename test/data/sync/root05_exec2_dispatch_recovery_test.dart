import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueStore implements SyncQueueStoreContract {
  final List<SyncOperation> items = <SyncOperation>[];
  bool failNextRead = false;

  @override
  Future<void> enqueue(SyncOperation operation) async => items.add(operation);

  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    items
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('planned queue read failure');
    }
    return List<SyncOperation>.from(items);
  }

  @override
  Future<void> removeById(String operationId) async {
    items.removeWhere((SyncOperation item) => item.operationId == operationId);
  }

  @override
  Future<void> update(SyncOperation updated) async {
    final int index = items.indexWhere(
      (SyncOperation item) => item.operationId == updated.operationId,
    );
    if (index >= 0) {
      items[index] = updated;
    }
  }
}

void main() {
  group('Root-05 EXEC-2 dispatcher and recovery', () {
    test(
      'T11 DISPATCH-H01/H02 settles serialized accepted dispatches',
      () async {
        final _QueueStore queue = _QueueStore();
        final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
          queueStore: queue,
          userId: 'user-a',
        );

        await Future.wait(<Future<bool>>[
          dispatcher.enqueueUpsert(
            tableName: 'tasks',
            recordId: 'one',
            payload: const <String, dynamic>{},
          ),
          dispatcher.enqueueUpsert(
            tableName: 'tasks',
            recordId: 'two',
            payload: const <String, dynamic>{},
          ),
        ]);
        await dispatcher.cancelAndDrain();

        expect(queue.items.map((SyncOperation item) => item.recordId), <String>[
          'one',
          'two',
        ]);
      },
    );

    test(
      'T12 DISPATCH-H03 gates transition work and keeps scope fixed',
      () async {
        final _QueueStore queue = _QueueStore();
        final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
          queueStore: queue,
          userId: 'user-a',
        );

        final Future<bool> pending = dispatcher.enqueueUpsert(
          tableName: 'tasks',
          recordId: 'a',
          payload: const <String, dynamic>{},
        );
        await dispatcher.cancelAndDrain();

        expect(await pending, isFalse);
        expect(
          await dispatcher.enqueueUpsert(
            tableName: 'tasks',
            recordId: 'b',
            payload: const <String, dynamic>{},
          ),
          isFalse,
        );
        expect(queue.items, isEmpty);
      },
    );

    test(
      'T13 DISPATCH-H03 recovers the operation tail after failure',
      () async {
        final _QueueStore queue = _QueueStore()..failNextRead = true;
        final SyncMutationDispatcher dispatcher = SyncMutationDispatcher(
          queueStore: queue,
          userId: 'user-a',
        );

        await expectLater(
          dispatcher.enqueueUpsert(
            tableName: 'tasks',
            recordId: 'failed',
            payload: const <String, dynamic>{},
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          await dispatcher.enqueueUpsert(
            tableName: 'tasks',
            recordId: 'recovered',
            payload: const <String, dynamic>{},
          ),
          isTrue,
        );
        expect(queue.items.single.recordId, 'recovered');
      },
    );

    test(
      'T14 RECOVERY-H01 drains without deleting scoped recovery data',
      () async {
        await SharedPrefsService.init();
        await SharedPrefsService.clear();
        final SessionRecoveryService service = SessionRecoveryService(
          storageScope: 'user-a',
        );

        await service.saveState(lastRoute: '/a', activeTaskId: 'task-a');
        await service.cancelAndDrain();

        final SessionRecoveryService recreated = SessionRecoveryService(
          storageScope: 'user-a',
        );
        expect((await recreated.loadState())?.lastRoute, '/a');
        expect((await recreated.loadState())?.activeTaskId, 'task-a');
      },
    );
  });
}
