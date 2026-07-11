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
    hiveDirectory = await Directory.systemTemp.createTemp('chronospark_offline_queue_');
    Hive.init(hiveDirectory.path);
    queueStorage = HiveStorage<String>('offline_sync_queue_box', hive: _TestHiveStore());
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
    await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'sync_to_cloud');
    await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'sync_to_cloud');

    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.actionType, 'sync_to_cloud');
  });

  test('replay updates attempts and removes successful entries', () async {
    await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'sync_to_cloud');

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
    await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'sync_to_cloud');

    final int processed = await service.replay(executor: (_) async => false);

    expect(processed, 1);
    final List<OfflineSyncQueueItem> queue = await service.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.attempts, 1);
    expect(queue.single.lastAttemptAtUtc, isNotNull);
  });

  test('replay respects maxItems', () async {
    await service.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'sync_to_cloud_1');
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
