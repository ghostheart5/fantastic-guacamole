import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineSyncQueueItem', () {
    test('fromJson normalizes payload keys and defaults missing primitives', () {
      final OfflineSyncQueueItem item = OfflineSyncQueueItem.fromJson(
        <String, dynamic>{
          'id': 'evt-1',
          'actionType': 'upsert_task',
          'dedupeKey': 'task:1',
          'payload': <dynamic, dynamic>{1: 'a', 'b': 2},
          'enqueuedAtUtc': '2026-08-01T00:00:00.000Z',
          'attempts': 2.0,
        },
      );

      expect(item.id, 'evt-1');
      expect(item.actionType, 'upsert_task');
      expect(item.dedupeKey, 'task:1');
      expect(item.payload.keys, containsAll(<String>['1', 'b']));
      expect(item.attempts, 2);
      expect(item.lastAttemptAtUtc, isNull);
    });

    test('toJson and copyWith preserve immutable queue item fields', () {
      const OfflineSyncQueueItem original = OfflineSyncQueueItem(
        id: 'evt-2',
        actionType: 'delete_task',
        dedupeKey: 'task:2',
        payload: <String, dynamic>{'hard': true},
        enqueuedAtUtc: '2026-08-01T01:00:00.000Z',
        attempts: 0,
      );

      final OfflineSyncQueueItem attempted = original.copyWith(
        attempts: 1,
        lastAttemptAtUtc: '2026-08-01T01:05:00.000Z',
      );

      expect(attempted.id, original.id);
      expect(attempted.actionType, original.actionType);
      expect(attempted.dedupeKey, original.dedupeKey);
      expect(attempted.payload, original.payload);
      expect(attempted.attempts, 1);
      expect(attempted.lastAttemptAtUtc, '2026-08-01T01:05:00.000Z');

      final Map<String, dynamic> encoded = attempted.toJson();
      expect(encoded['id'], 'evt-2');
      expect(encoded['attempts'], 1);
      expect(encoded['lastAttemptAtUtc'], '2026-08-01T01:05:00.000Z');
    });
  });
}
