import 'dart:convert';

import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsStorage prefs;
  late OfflineSyncQueueService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = SharedPrefsStorage(await SharedPreferences.getInstance());
    service = OfflineSyncQueueService(prefs);
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
    final SharedPreferences raw = await SharedPreferences.getInstance();
    await raw.setString(
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
