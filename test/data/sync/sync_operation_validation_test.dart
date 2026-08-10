import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> validPayload() => <String, dynamic>{
  'operationId': 'operation-1',
  'tableName': 'tasks',
  'recordId': 'task-1',
  'operationType': 'update',
  'payload': <String, dynamic>{'title': 'Focus'},
  'userId': 'user-1',
  'createdAtUtc': '2026-08-04T12:00:00.000Z',
  'retryCount': 0,
  'nextRetryAtUtc': null,
  'lastError': null,
};

void main() {
  test('rejects queue entries missing required operation fields', () {
    for (final String key in <String>[
      'operationType',
      'recordId',
      'payload',
      'retryCount',
      'createdAtUtc',
    ]) {
      final Map<String, dynamic> payload = validPayload()..remove(key);
      expect(() => SyncOperation.fromJson(payload), throwsFormatException);
    }
  });

  test(
    'rejects invalid operation metadata instead of defaulting to update',
    () {
      final Map<String, dynamic> payload = validPayload()
        ..['operationType'] = 'unknown'
        ..['createdAtUtc'] = 'not-a-date';

      expect(() => SyncOperation.fromJson(payload), throwsFormatException);
    },
  );
}
