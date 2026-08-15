import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_sync_queue_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final NotifierProvider<_Scope, AccountStorageScope> _scopeProvider =
    NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

class _Scope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope scope) => state = scope;
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('sync-provider-scope-').path));

  test('real dispatcher and store recreate A to B to A', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);

    await _set(container, AccountStorageScope.authenticated('A'));
    final SyncMutationDispatcher dispatcherA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    expect(
      await dispatcherA.enqueueUpsert(
        tableName: 'tasks',
        recordId: 'A_SECRET_SYNC_OP',
        payload: const <String, dynamic>{'title': 'A_SECRET_SYNC_OP'},
      ),
      isTrue,
    );

    await _set(container, AccountStorageScope.authenticated('B'));
    final SyncMutationDispatcher dispatcherB = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeB = container.read(syncQueueStoreProvider);
    expect(identical(dispatcherA, dispatcherB), isFalse);
    expect(identical(storeA, storeB), isFalse);
    expect(await storeB.readAll(), isEmpty);
    expect(
      await dispatcherB.enqueueUpsert(
        tableName: 'tasks',
        recordId: 'B_SECRET_SYNC_OP',
        payload: const <String, dynamic>{'title': 'B_SECRET_SYNC_OP'},
      ),
      isTrue,
    );

    // A retained dispatcher must not be able to act after its scope is no
    // longer current; otherwise an in-flight A producer can outlive handoff.
    expect(
      await dispatcherA.enqueueUpsert(
        tableName: 'tasks',
        recordId: 'STALE_A_OP',
        payload: const <String, dynamic>{'title': 'STALE_A_OP'},
      ),
      isFalse,
    );

    await _set(container, AccountStorageScope.authenticated('A'));
    final List<SyncOperation> aItems =
        await container.read(syncQueueStoreProvider).readAll();
    expect(
      aItems.map((SyncOperation item) => item.recordId),
      <String>['A_SECRET_SYNC_OP'],
    );
    expect((await storeB.readAll()).single.recordId, 'B_SECRET_SYNC_OP');
  });

  test('A dispatcher is revoked on signed-out handoff', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('signed-out-A'));
    final SyncMutationDispatcher dispatcherA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'EXISTING_A', payload: const <String, dynamic>{},
    ), isTrue);

    await _set(container, const AccountStorageScope.signedOut());
    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_SIGNED_OUT_A', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await container.read(syncQueueStoreProvider).readAll(), isEmpty);
    expect((await storeA.readAll()).single.recordId, 'EXISTING_A');
  });

  test('only final C dispatcher is authorized after rapid A to B to C', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('rapid-A'));
    final SyncMutationDispatcher dispatcherA = container.read(syncMutationDispatcherProvider);
    await _set(container, AccountStorageScope.authenticated('rapid-B'));
    final SyncMutationDispatcher dispatcherB = container.read(syncMutationDispatcherProvider);
    await _set(container, AccountStorageScope.authenticated('rapid-C'));
    final SyncMutationDispatcher dispatcherC = container.read(syncMutationDispatcherProvider);

    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_A', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await dispatcherB.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_B', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await dispatcherC.enqueueUpsert(
      tableName: 'tasks', recordId: 'CURRENT_C', payload: const <String, dynamic>{},
    ), isTrue);
    expect((await container.read(syncQueueStoreProvider).readAll()).single.recordId, 'CURRENT_C');
  });

  test('returning to A requires a fresh dispatcher lease', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('return-A'));
    final SyncMutationDispatcher originalA = container.read(syncMutationDispatcherProvider);
    await _set(container, AccountStorageScope.authenticated('return-B'));
    await _set(container, AccountStorageScope.authenticated('return-A'));
    final SyncMutationDispatcher freshA = container.read(syncMutationDispatcherProvider);

    expect(identical(originalA, freshA), isFalse);
    expect(await originalA.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_RETURN_A', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await freshA.enqueueUpsert(
      tableName: 'tasks', recordId: 'FRESH_RETURN_A', payload: const <String, dynamic>{},
    ), isTrue);
  });

  test('late A replay completion only acknowledges A storage after B handoff', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('replay-A'));
    final SyncMutationDispatcher dispatcherA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'A_OP', payload: const <String, dynamic>{},
    ), isTrue);

    final Completer<void> started = Completer<void>();
    final Completer<SyncApplyResult> release = Completer<SyncApplyResult>();
    final SyncRunner runnerA = SyncRunner(
      queueStore: storeA,
      applyFn: (SyncOperation _) {
        started.complete();
        return release.future;
      },
    );
    final Future<void> replay = runnerA.runOnce();
    await started.future;

    await _set(container, AccountStorageScope.authenticated('replay-B'));
    final SyncMutationDispatcher dispatcherB = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeB = container.read(syncQueueStoreProvider);
    expect(await dispatcherB.enqueueUpsert(
      tableName: 'tasks', recordId: 'B_OP', payload: const <String, dynamic>{},
    ), isTrue);
    release.complete(SyncApplyResult.success());
    await replay;

    expect(await storeA.readAll(), isEmpty);
    expect((await storeB.readAll()).single.recordId, 'B_OP');
    expect(await container.read(supabaseSyncQueueCountProvider.future), 1);
  });

  test('failure and retry stay account-local across B success', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('failure-A'));
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    await storeA.enqueue(_operation('failure-A', 'same-id'));
    await SyncRunner(
      queueStore: storeA,
      applyFn: (SyncOperation _) async => SyncApplyResult.retryable('network'),
      now: () => DateTime.utc(2026, 8, 14),
    ).runOnce();
    expect((await storeA.readAll()).single.retryCount, 1);

    await _set(container, AccountStorageScope.authenticated('failure-B'));
    final SyncQueueStore storeB = container.read(syncQueueStoreProvider);
    await storeB.enqueue(_operation('failure-B', 'same-id'));
    await SyncRunner(
      queueStore: storeB,
      applyFn: (SyncOperation _) async => SyncApplyResult.success(),
    ).runOnce();
    expect(await storeB.readAll(), isEmpty);
    expect((await storeA.readAll()).single.retryCount, 1);
  });

  test('signed-out projection is empty and B cannot hydrate A queue', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('signed-chain-A'));
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    await storeA.enqueue(_operation('signed-chain-A', 'A_PARKED'));
    await _set(container, const AccountStorageScope.signedOut());
    expect(await container.read(syncQueueStoreProvider).readAll(), isEmpty);
    expect(await container.read(supabaseSyncQueueCountProvider.future), 0);
    await _set(container, AccountStorageScope.authenticated('signed-chain-B'));
    expect(await container.read(syncQueueStoreProvider).readAll(), isEmpty);
    expect((await storeA.readAll()).single.recordId, 'A_PARKED');
  });

  test('held A and B replays cannot mutate final C queue', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('rapid-replay-A'));
    final SyncMutationDispatcher dispatcherA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'A_OP', payload: const <String, dynamic>{},
    ), isTrue);
    final Completer<SyncApplyResult> releaseA = Completer<SyncApplyResult>();
    final SyncRunner runnerA = SyncRunner(
      queueStore: storeA,
      applyFn: (SyncOperation _) => releaseA.future,
    );
    final Future<void> replayA = runnerA.runOnce();

    await _set(container, AccountStorageScope.authenticated('rapid-replay-B'));
    final SyncMutationDispatcher dispatcherB = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeB = container.read(syncQueueStoreProvider);
    expect(await dispatcherB.enqueueUpsert(
      tableName: 'tasks', recordId: 'B_OP', payload: const <String, dynamic>{},
    ), isTrue);
    final Completer<SyncApplyResult> releaseB = Completer<SyncApplyResult>();
    final Future<void> replayB = SyncRunner(
      queueStore: storeB,
      applyFn: (SyncOperation _) => releaseB.future,
    ).runOnce();

    await _set(container, AccountStorageScope.authenticated('rapid-replay-C'));
    final SyncMutationDispatcher dispatcherC = container.read(syncMutationDispatcherProvider);
    expect(await dispatcherA.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_A', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await dispatcherB.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_B', payload: const <String, dynamic>{},
    ), isFalse);
    expect(await dispatcherC.enqueueUpsert(
      tableName: 'tasks', recordId: 'C_OP', payload: const <String, dynamic>{},
    ), isTrue);
    releaseA.complete(SyncApplyResult.success());
    releaseB.complete(SyncApplyResult.success());
    await Future.wait(<Future<void>>[replayA, replayB]);
    expect((await container.read(syncQueueStoreProvider).readAll()).single.recordId, 'C_OP');
  });

  test('fresh A runner retries A failure without touching B', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('retry-A'));
    final SyncMutationDispatcher originalA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore storeA = container.read(syncQueueStoreProvider);
    await storeA.enqueue(_operation('retry-A', 'A_FAIL_OP'));
    await SyncRunner(
      queueStore: storeA,
      applyFn: (SyncOperation _) async => SyncApplyResult.retryable('network'),
      now: () => DateTime.utc(2026, 8, 14),
    ).runOnce();
    await _set(container, AccountStorageScope.authenticated('retry-B'));
    final SyncQueueStore storeB = container.read(syncQueueStoreProvider);
    await storeB.enqueue(_operation('retry-B', 'B_OP'));
    await _set(container, AccountStorageScope.authenticated('retry-A'));
    final SyncMutationDispatcher freshA = container.read(syncMutationDispatcherProvider);
    final SyncQueueStore freshStoreA = container.read(syncQueueStoreProvider);
    expect(identical(originalA, freshA), isFalse);
    expect(await originalA.enqueueUpsert(
      tableName: 'tasks', recordId: 'STALE_A', payload: const <String, dynamic>{},
    ), isFalse);
    await SyncRunner(
      queueStore: freshStoreA,
      applyFn: (SyncOperation _) async => SyncApplyResult.success(),
      now: () => DateTime.utc(2026, 8, 14, 0, 1),
    ).runOnce();
    expect(await freshStoreA.readAll(), isEmpty);
    expect((await storeB.readAll()).single.recordId, 'B_OP');
  });

  test('fresh containers hydrate only their authenticated V2 queue', () async {
    final ProviderContainer first = _container();
    await _set(first, AccountStorageScope.authenticated('restart-chain-A'));
    await first.read(syncQueueStoreProvider).enqueue(_operation('restart-chain-A', 'A_RESTART_OP'));
    first.dispose();

    final ProviderContainer restartedA = _container();
    addTearDown(restartedA.dispose);
    await _set(restartedA, AccountStorageScope.authenticated('restart-chain-A'));
    expect((await restartedA.read(syncQueueStoreProvider).readAll()).single.recordId, 'A_RESTART_OP');
    expect(await restartedA.read(supabaseSyncQueueCountProvider.future), 1);
    final SyncMutationDispatcher aDispatcher = restartedA.read(syncMutationDispatcherProvider);

    final ProviderContainer restartedB = _container();
    addTearDown(restartedB.dispose);
    await _set(restartedB, AccountStorageScope.authenticated('restart-chain-B'));
    expect(await restartedB.read(syncQueueStoreProvider).readAll(), isEmpty);
    expect(await restartedB.read(supabaseSyncQueueCountProvider.future), 0);
    expect(await aDispatcher.enqueueUpsert(
      tableName: 'tasks', recordId: 'A_FRESH', payload: const <String, dynamic>{},
    ), isTrue);
  });

  test('real flush provider uses an overrideable transport boundary', () async {
    final List<String> sentUsers = <String>[];
    final ProviderContainer container = _container(
      applyFn: (SyncOperation operation) async {
        sentUsers.add(operation.userId);
        return SyncApplyResult.success();
      },
    );
    addTearDown(container.dispose);
    await _set(container, AccountStorageScope.authenticated('flush-seam-A'));
    await container.read(syncQueueStoreProvider).enqueue(
      _operation('flush-seam-A', 'A_FLUSH_OP'),
    );

    expect(await container.read(flushSupabaseSyncQueueProvider.future), 0);
    expect(sentUsers, <String>['flush-seam-A']);
    expect(await container.read(supabaseSyncQueueCountProvider.future), 0);
  });
}

SyncOperation _operation(String userId, String operationId) => SyncOperation(
  operationId: operationId,
  tableName: 'tasks',
  recordId: operationId,
  operationType: SyncOperationType.update,
  payload: <String, dynamic>{'user_id': userId},
  userId: userId,
  createdAtUtc: DateTime.utc(2026, 8, 14),
  retryCount: 0,
  nextRetryAtUtc: null,
  lastError: null,
);

ProviderContainer _container({SyncApplyFn? applyFn}) => ProviderContainer(
  overrides: [
    hiveStoreProvider.overrideWithValue(const _Hive()),
    if (applyFn != null) supabaseSyncApplyProvider.overrideWithValue(applyFn),
    accountStorageScopeProvider.overrideWith(
      (Ref ref) => ref.watch(_scopeProvider),
    ),
  ],
);

Future<void> _set(ProviderContainer container, AccountStorageScope scope) async {
  container.read(_scopeProvider.notifier).set(scope);
  container.invalidate(syncMutationDispatcherProvider);
  container.invalidate(syncQueueStoreProvider);
  await Future<void>.delayed(Duration.zero);
}
