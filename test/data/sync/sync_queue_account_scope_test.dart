import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Hive implements HiveStore {
  const _Hive();

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();

  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

const HiveStore _hive = _Hive();

SyncQueueStore _store(AccountStorageScope scope) => SyncQueueStore(
  HiveStorage<String>(
    HiveBoxes.accountScoped(HiveBoxes.offlineQueue, scope),
    hive: _hive,
  ),
  storageScope: scope,
);

SyncOperation _operation(String userId, String label) => SyncOperation(
  operationId: 'same-operation-id',
  tableName: 'tasks',
  recordId: 'same-record-id',
  operationType: SyncOperationType.update,
  payload: <String, dynamic>{'secret': label},
  userId: userId,
  createdAtUtc: DateTime.utc(2026, 8, 14),
  retryCount: 0,
  nextRetryAtUtc: null,
  lastError: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AccountStorageScope a = AccountStorageScope.authenticated('sync-A');
  final AccountStorageScope b = AccountStorageScope.authenticated('sync-B');

  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('sync-scope-').path));

  test('V2 sync queues isolate A to B to A, including identical operation IDs', () async {
    await _store(a).enqueue(_operation('sync-A', 'A_SECRET_SYNC_OP'));
    expect((await _store(b).readAll()), isEmpty);

    await _store(b).enqueue(_operation('sync-B', 'B_SECRET_SYNC_OP'));
    expect((await _store(a).readAll()).single.payload['secret'], 'A_SECRET_SYNC_OP');
    expect((await _store(b).readAll()).single.payload['secret'], 'B_SECRET_SYNC_OP');
  });

  test('acknowledging A does not remove B operation with the same operation ID', () async {
    await _store(a).removeById('same-operation-id');
    expect((await _store(a).readAll()), isEmpty);
    expect((await _store(b).readAll()).single.payload['secret'], 'B_SECRET_SYNC_OP');
  });

  test('signed-out store exposes no queue and cannot write', () async {
    final SyncQueueStore signedOut = SyncQueueStore.unavailable();
    expect(await signedOut.readAll(), isEmpty);
    await expectLater(
      signedOut.enqueue(_operation('sync-A', 'must-not-write')),
      throwsStateError,
    );
  });

  test('legacy global queue remains inactive and unclaimed', () async {
    final HiveStorage<String> legacy = HiveStorage<String>(
      HiveBoxes.offlineQueue,
      hive: _hive,
    );
    const String sentinel = '[{"legacy":"do-not-claim"}]';
    await legacy.put(SyncQueueStore.legacyStorageKey, sentinel);

    expect(await _store(AccountStorageScope.authenticated('legacy-user')).readAll(), isEmpty);
    await legacy.open();
    expect(legacy.get(SyncQueueStore.legacyStorageKey), sentinel);
  });

  test('restart and replay use only the current account V2 queue', () async {
    final List<String> applied = <String>[];
    final SyncRunner runner = SyncRunner(
      queueStore: _store(b),
      applyFn: (SyncOperation operation) async {
        applied.add(operation.userId);
        return SyncApplyResult.success();
      },
    );
    await runner.runOnce();

    expect(applied, <String>['sync-B']);
    expect(await _store(b).readAll(), isEmpty);
    expect((await _store(a).readAll()), isEmpty);
  });
}
