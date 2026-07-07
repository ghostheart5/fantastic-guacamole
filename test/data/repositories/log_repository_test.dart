import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStoreBackend backend;
  late LogRepository repository;

  setUp(() {
    backend = InMemorySecureStoreBackend();
    repository = LogRepository(SecureStore(backend: backend));
  });

  test('starts with an empty history instead of placeholder entries', () async {
    expect(await repository.getLogs(), isEmpty);
  });

  test('persists entries newest first', () async {
    final DateTime earlier = DateTime.utc(2026, 7, 4, 12);
    final DateTime later = earlier.add(const Duration(minutes: 25));

    await repository.addLog(
      LogEntryEntity(
        id: 'earlier',
        message: 'First session',
        source: 'focus_session',
        timestamp: earlier,
      ),
    );
    await repository.addLog(
      LogEntryEntity(
        id: 'later',
        message: 'Completed task',
        source: 'completed_task',
        timestamp: later,
      ),
    );

    final List<LogEntryEntity> entries = await repository.getLogs();
    expect(entries.map((LogEntryEntity entry) => entry.id), <String>['later', 'earlier']);
  });

  test('replaces an existing entry with the same id', () async {
    final DateTime timestamp = DateTime.utc(2026, 7, 4, 12);
    await repository.addLog(
      LogEntryEntity(id: 'same', message: 'Old', source: 'daily_log', timestamp: timestamp),
    );
    await repository.addLog(
      LogEntryEntity(id: 'same', message: 'Updated', source: 'daily_log', timestamp: timestamp),
    );

    final List<LogEntryEntity> entries = await repository.getLogs();
    expect(entries, hasLength(1));
    expect(entries.single.message, 'Updated');
  });

  test('returns empty logs when persisted storage is corrupt', () async {
    await SecureStore(backend: backend).writeString('chrono_log_entries_v2', '{not-json');

    final List<LogEntryEntity> entries = await Logger.withMutedErrors(() => repository.getLogs());

    expect(entries, isEmpty);
  });

  test('skips malformed entries but keeps valid ones', () async {
    await SecureStore(backend: backend).writeString(
      'chrono_log_entries_v2',
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'valid-1',
          'message': 'Valid',
          'source': 'daily_log',
          'timestamp': DateTime.utc(2026, 7, 5).toIso8601String(),
        },
        <String, Object?>{
          'id': '',
          'message': 'Invalid',
          'source': 'daily_log',
          'timestamp': DateTime.utc(2026, 7, 5).toIso8601String(),
        },
      ]),
    );

    final entries = await repository.getLogs();

    expect(entries, hasLength(1));
    expect(entries.single.id, 'valid-1');
  });

  test('clear removes stored logs', () async {
    await repository.addLog(
      LogEntryEntity(
        id: 'to-clear',
        message: 'wipe me',
        source: 'daily_log',
        timestamp: DateTime.utc(2026, 7, 5),
      ),
    );

    await repository.clear();

    expect(await repository.getLogs(), isEmpty);
  });
}
