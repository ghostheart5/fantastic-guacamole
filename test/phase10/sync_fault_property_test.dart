import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/phase10/deterministic_generators.dart';

class _Queue implements SyncQueueStoreContract {
  _Queue(List<SyncOperation> items) : _items = List<SyncOperation>.from(items);

  final List<SyncOperation> _items;
  bool failNextUpdate = false;

  @override
  Future<void> enqueue(SyncOperation operation) async => _items.add(operation);

  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    _items
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async => List<SyncOperation>.from(_items);

  @override
  Future<void> removeById(String operationId) async {
    _items.removeWhere((SyncOperation item) => item.operationId == operationId);
  }

  @override
  Future<void> update(SyncOperation updated) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('injected local storage failure');
    }
    final int index = _items.indexWhere(
      (SyncOperation item) => item.operationId == updated.operationId,
    );
    if (index >= 0) _items[index] = updated;
  }
}

SyncOperation _operation({
  required String id,
  required String userId,
  required DateTime createdAt,
}) {
  return SyncOperation(
    operationId: id,
    tableName: 'tasks',
    recordId: 'record-$id',
    operationType: SyncOperationType.update,
    payload: <String, dynamic>{'title': 'task-$id'},
    userId: userId,
    createdAtUtc: createdAt,
    retryCount: 0,
    nextRetryAtUtc: null,
    lastError: null,
  );
}

void main() {
  test('fixed response faults preserve per-user queue ownership and one final outcome', () async {
    const List<String> retryableFaults = <String>[
      'latency',
      'packet-loss',
      'offline',
      'dns-failure',
      'http-401',
      'http-409',
      'http-429',
      'http-500',
      'timeout',
      'malformed-json',
      'missing-fields',
      'duplicate-response',
      'out-of-order-response',
      'partial-write',
      'plugin-failure',
      'clock-skew',
    ];
    for (final int seed in phase10Seeds) {
      final DeterministicGenerator g = DeterministicGenerator(seed);
      DateTime now = DateTime.utc(2026, 1, 1);
      final SyncOperation userA = _operation(
        id: 'a-$seed',
        userId: 'user-a',
        createdAt: now,
      );
      final SyncOperation userB = _operation(
        id: 'b-$seed',
        userId: 'user-b',
        createdAt: now,
      );
      final _Queue queue = _Queue(<SyncOperation>[userA, userB]);
      final String fault = retryableFaults[g.between(0, retryableFaults.length - 1)];
      bool failUserAOnce = true;
      final SyncRunner runner = SyncRunner(
        queueStore: queue,
        now: () => now,
        applyFn: (SyncOperation operation) async {
          if (operation.userId == 'user-a' && failUserAOnce) {
            failUserAOnce = false;
            return SyncApplyResult.retryable(fault);
          }
          return SyncApplyResult.success();
        },
      );

      await runner.runOnce();
      final List<SyncOperation> afterFailure = await queue.readAll();
      expect(afterFailure, hasLength(1), reason: 'seed=$seed');
      expect(afterFailure.single.userId, 'user-a', reason: 'seed=$seed');
      expect(afterFailure.single.retryCount, 1, reason: 'seed=$seed');
      now = afterFailure.single.nextRetryAtUtc!;
      await runner.runOnce();
      expect(await queue.readAll(), isEmpty, reason: 'seed=$seed');
    }
  });

  test('malformed sync payloads fail closed', () {
    for (final String payload in <String>[
      '',
      'null',
      '[]',
      '{}',
      '{"operationId":"x"}',
      '{"operationId":"x","tableName":"tasks","recordId":"r","userId":"a","operationType":"unknown","payload":{},"createdAtUtc":"2026-01-01T00:00:00Z","retryCount":0}',
    ]) {
      expect(() => SyncOperation.decode(payload), throwsFormatException);
    }
  });

  test('local storage failure leaves no half-completed transition and runner recovers', () async {
    final _Queue queue = _Queue(<SyncOperation>[
      _operation(
        id: 'storage',
        userId: 'user-a',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ])..failNextUpdate = true;
    bool retry = true;
    final SyncRunner runner = SyncRunner(
      queueStore: queue,
      now: () => DateTime.utc(2026, 1, 1),
      applyFn: (SyncOperation _) async {
        if (retry) {
          retry = false;
          return SyncApplyResult.retryable('disk-full');
        }
        return SyncApplyResult.success();
      },
    );

    await expectLater(runner.runOnce(), throwsStateError);
    final List<SyncOperation> afterFailure = await queue.readAll();
    expect(afterFailure, hasLength(1));
    expect(afterFailure.single.retryCount, 0);

    await runner.runOnce();
    expect(await queue.readAll(), isEmpty);
  });
}
