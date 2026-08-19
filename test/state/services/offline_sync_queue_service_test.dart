import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late HiveStorage<String> queueStorage;
  late OfflineSyncQueueService service;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_offline_queue_',
    );
    Hive.init(hiveDirectory.path);
    queueStorage = HiveStorage<String>(
      'offline_sync_queue_box',
      hive: _TestHiveStore(),
    );
    service = OfflineSyncQueueService(queueStorage);
  });

  tearDown(() async {
    await queueStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('enqueue dedupes by dedupeKey', () async {
    await service.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'sync_to_cloud',
    );
    await service.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'sync_to_cloud',
    );

    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.actionType, 'sync_to_cloud');
  });

  test('serializes concurrent enqueues without losing either item', () async {
    await Future.wait(<Future<void>>[
      service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'first'),
      service.enqueue(actionType: 'sync_delta', dedupeKey: 'second'),
    ]);

    expect(await service.queuedCount(), 2);
  });

  test('account-bound queues cannot read or replay another account', () async {
    final OfflineSyncQueueService accountA = OfflineSyncQueueService(
      queueStorage,
      accountId: 'account-a',
      enforceAccountBinding: true,
    );
    final OfflineSyncQueueService accountB = OfflineSyncQueueService(
      queueStorage,
      accountId: 'account-b',
      enforceAccountBinding: true,
    );

    await accountA.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'account-a-sync',
    );

    expect(await accountA.queuedCount(), 1);
    expect(await accountB.queuedCount(), 0);
    expect(
      await accountB.replay(
        executor: (_) async =>
            fail('another account must never replay this item'),
      ),
      0,
    );
  });

  test('replay updates attempts and removes successful entries', () async {
    await service.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'sync_to_cloud',
    );

    final int processed = await service.replay(
      executor: (OfflineSyncQueueItem item) async {
        expect(item.attempts, 1);
        expect(item.lastAttemptAtUtc, isNotNull);
        return true;
      },
    );

    expect(processed, 1);
    expect(await service.queuedCount(), 0);
  });

  test('replay keeps failed entries and increments attempts', () async {
    await service.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'sync_to_cloud',
    );

    final int processed = await service.replay(executor: (_) async => false);

    expect(processed, 1);
    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.attempts, 1);
    expect(queue.single.lastAttemptAtUtc, isNotNull);
  });

  test('dead-lettered entries are visible and can be retried', () async {
    final DateTime now = DateTime.utc(2026, 2, 1);
    await queueStorage.put(
      OfflineSyncQueueService.storageKey,
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'dead',
          'actionType': 'sync_to_cloud',
          'dedupeKey': 'sync_to_cloud',
          'payload': <String, dynamic>{},
          'enqueuedAtUtc': now.toIso8601String(),
          'attempts': OfflineSyncQueueService.maxAttempts,
          'lastAttemptAtUtc': now.toIso8601String(),
          'deadLettered': true,
        },
      ]),
    );

    expect(await service.deadLetteredCount(), 1);
    expect((await service.deadLetteredItems()).single.deadLettered, isTrue);

    expect(await service.retryDeadLetters(), 1);
    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue.single.deadLettered, isFalse);
    expect(queue.single.attempts, 0);
  });

  test('expired dead letters are pruned by retention policy', () async {
    final DateTime old = DateTime.utc(2026, 1, 1);
    await queueStorage.put(
      OfflineSyncQueueService.storageKey,
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'dead-old',
          'actionType': 'sync_to_cloud',
          'dedupeKey': 'dead-old',
          'payload': <String, dynamic>{},
          'enqueuedAtUtc': old.toIso8601String(),
          'attempts': OfflineSyncQueueService.maxAttempts,
          'lastAttemptAtUtc': old.toIso8601String(),
          'deadLettered': true,
        },
        <String, dynamic>{
          'id': 'live',
          'actionType': 'sync_to_cloud',
          'dedupeKey': 'live',
          'payload': <String, dynamic>{},
          'enqueuedAtUtc': DateTime.utc(2026, 2, 1).toIso8601String(),
          'attempts': 0,
        },
      ]),
    );

    expect(
      await service.pruneExpiredDeadLetters(
        nowUtc: old.add(OfflineSyncQueueService.deadLetterRetention),
      ),
      1,
    );
    expect(
      (await service.loadQueue()).map((OfflineSyncQueueItem item) => item.id),
      <String>['live'],
    );
  });

  test('replay respects maxItems', () async {
    await service.enqueue(
      actionType: 'sync_to_cloud',
      dedupeKey: 'sync_to_cloud_1',
    );
    await service.enqueue(actionType: 'sync_delta', dedupeKey: 'sync_delta_1');

    int executions = 0;
    final int processed = await service.replay(
      maxItems: 1,
      executor: (_) async {
        executions += 1;
        return false;
      },
    );

    expect(processed, 1);
    expect(executions, 1);
    expect(await service.queuedCount(), 2);
  });

  test('loadQueue ignores malformed entries', () async {
    await queueStorage.put(
      OfflineSyncQueueService.storageKey,
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': '',
          'actionType': 'sync_to_cloud',
          'dedupeKey': 'bad_empty_id',
          'payload': <String, dynamic>{},
          'enqueuedAtUtc': DateTime.now().toUtc().toIso8601String(),
          'attempts': 0,
        },
        <String, dynamic>{
          'id': 'good-id',
          'actionType': 'sync_to_cloud',
          'dedupeKey': 'good',
          'payload': <String, dynamic>{},
          'enqueuedAtUtc': DateTime.now().toUtc().toIso8601String(),
          'attempts': 0,
        },
      ]),
    );

    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.id, 'good-id');
  });

  test(
    'preserves a corrupt queue payload before a later enqueue replaces it',
    () async {
      const String corruptPayload = '{not-json';
      await queueStorage.put(
        OfflineSyncQueueService.storageKey,
        corruptPayload,
      );

      expect(await service.loadQueue(), isEmpty);
      await service.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'replacement',
      );

      final Box<String> box = Hive.box<String>('offline_sync_queue_box');
      expect(
        box.get(OfflineSyncQueueService.corruptStorageKey),
        corruptPayload,
      );
      expect(await service.queuedCount(), 1);
    },
  );

  test(
    'replay checkpoints each completed item before processing the next item',
    () async {
      await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'first');
      await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'second');

      List<OfflineSyncQueueItem>? queueSeenDuringSecondItem;
      int handled = 0;

      await service.replay(
        executor: (OfflineSyncQueueItem item) async {
          handled++;
          if (handled == 2) {
            queueSeenDuringSecondItem = await service.loadQueue();
          }
          return true;
        },
      );

      expect(handled, 2);
      expect(
        queueSeenDuringSecondItem,
        hasLength(1),
        reason:
            'The first successful item must be durable before the next '
            'executor invocation begins.',
      );

      expect(await service.queuedCount(), 0);
    },
  );
}

class _TestHiveStore implements HiveStore {
  @override
  Future<void> clearBox(String key) async {
    final Box<String> box = await openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }

  @override
  Box<T> box<T>(String key) {
    return Hive.box<T>(key);
  }

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) {
    return Hive.isBoxOpen(key);
  }

  @override
  Future<Box<T>> openBox<T>(String key) {
    if (Hive.isBoxOpen(key)) {
      return Future<Box<T>>.value(Hive.box<T>(key));
    }
    return Hive.openBox<T>(key);
  }
}
