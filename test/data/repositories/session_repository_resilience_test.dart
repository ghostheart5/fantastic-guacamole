import 'dart:convert';

import 'package:fantastic_guacamole/data/repositories/session_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skips malformed session rows and keeps valid rows', () async {
    final SecureStore store = SecureStore(backend: InMemorySecureStoreBackend());
    final SessionRepository repository = SessionRepository(store);

    await store.writeString(
      'sessions_entity_v1',
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'id': 's-1',
          'taskId': 'task-1',
          'startedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
          'endedAt': null,
          'plannedDurationMs': 120000,
        },
        <String, Object?>{
          'id': 's-2',
          'taskId': 'task-2',
          'startedAt': 'invalid-timestamp',
          'endedAt': null,
          'plannedDurationMs': 45000,
        },
      ]),
    );

    final sessions = await repository.getSessionsForTask('task-1');

    expect(sessions.length, 1);
    expect(sessions.first.id, 's-1');
    expect(sessions.first.taskId, 'task-1');
    expect(sessions.first.startedAt, DateTime.utc(2026, 1, 2));
  });

  test('surfaces top-level session corruption instead of flattening to empty', () async {
    final SecureStore store = SecureStore(backend: InMemorySecureStoreBackend());
    final SessionRepository repository = SessionRepository(store);

    await store.writeString('sessions_entity_v1', '{not-json');

    await expectLater(
      repository.getSessionsForTask('task-1'),
      throwsA(isA<StateError>()),
    );
  });
}
