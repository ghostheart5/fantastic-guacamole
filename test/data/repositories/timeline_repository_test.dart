import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/usecases/timeline_lifecycle_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String storageKey = 'timeline_events_v1';
  const String backupKey = 'timeline_events_v1_corrupt_backup';

  TimelineEventEntity event(String id) => TimelineEventEntity(
    id: id,
    type: TimelineEventType.task,
    title: 'Event $id',
    detail: 'Stored event $id',
    timestamp: DateTime.utc(2026, 8, 29, 12),
  );

  test(
    'missing and valid empty storage remain distinguishable from corruption',
    () {
      final _MemoryStore store = _MemoryStore();
      final TimelineRepository repository = TimelineRepository(store);

      expect(repository.getEvents(), isEmpty);
      expect(repository.lastReadCorrupted, isFalse);

      store.values[storageKey] = '[]';
      expect(repository.getEvents(), isEmpty);
      expect(repository.lastReadCorrupted, isFalse);
    },
  );

  test('valid activity round trips without a corruption marker', () async {
    final _MemoryStore store = _MemoryStore();
    final TimelineRepository repository = TimelineRepository(store);

    await repository.saveEvents(<TimelineEventEntity>[event('one')]);

    expect(repository.getEvents().single.id, 'one');
    expect(repository.lastReadCorrupted, isFalse);
    expect(store.values[backupKey], isNull);
  });

  test('malformed top-level storage is flagged and preserved', () async {
    final _MemoryStore store = _MemoryStore()
      ..values[storageKey] = '{"not":"a list"}';
    final TimelineRepository repository = TimelineRepository(store);

    await Logger.withMutedErrors(() async {
      expect(repository.getEvents(), isEmpty);
    });
    expect(repository.lastReadCorrupted, isTrue);

    await Logger.withMutedErrors(() => repository.addEvent(event('new')));

    expect(store.values[backupKey], '{"not":"a list"}');
    expect(repository.getEvents().single.id, 'new');
    expect(repository.lastReadCorrupted, isFalse);
  });

  test(
    'valid siblings survive a malformed record and raw data is quarantined',
    () async {
      final String raw = jsonEncode(<Object?>[
        event('valid').toJson(),
        <String, Object?>{'id': 'broken'},
        'wrong shape',
      ]);
      final _MemoryStore store = _MemoryStore()..values[storageKey] = raw;
      final TimelineRepository repository = TimelineRepository(store);

      await Logger.withMutedErrors(() async {
        expect(repository.getEvents().map((item) => item.id), <String>[
          'valid',
        ]);
      });
      expect(repository.lastReadCorrupted, isTrue);

      await Logger.withMutedErrors(() => repository.addEvent(event('new')));

      expect(store.values[backupKey], raw);
      expect(repository.getEvents().map((item) => item.id), <String>[
        'new',
        'valid',
      ]);
    },
  );

  test(
    'unknown enum values are quarantined instead of silently rewritten',
    () async {
      final Map<String, dynamic> unknownType = event('future-type').toJson()
        ..['type'] = 'futureType';
      final Map<String, dynamic> unknownStatus = event('future-status').toJson()
        ..['status'] = 'futureStatus';
      final String raw = jsonEncode(<Object?>[
        event('valid').toJson(),
        unknownType,
        unknownStatus,
      ]);
      final _MemoryStore store = _MemoryStore()..values[storageKey] = raw;
      final TimelineRepository repository = TimelineRepository(store);

      late List<TimelineEventEntity> validEvents;
      await Logger.withMutedErrors(() async {
        validEvents = repository.getEvents();
      });
      expect(validEvents.map((TimelineEventEntity item) => item.id), <String>[
        'valid',
      ]);
      expect(repository.lastReadCorrupted, isTrue);

      await Logger.withMutedErrors(() => repository.saveEvents(validEvents));

      expect(store.values[backupKey], raw);
      expect(repository.getEvents().map((item) => item.id), <String>['valid']);
      expect(repository.lastReadCorrupted, isFalse);
    },
  );

  test('a failed quarantine aborts the active overwrite', () async {
    const String raw = 'not json';
    final _MemoryStore store = _MemoryStore(failingSaveKey: backupKey)
      ..values[storageKey] = raw;
    final TimelineRepository repository = TimelineRepository(store);

    await Logger.withMutedErrors(() async {
      expect(repository.getEvents(), isEmpty);
      await expectLater(
        repository.saveEvents(<TimelineEventEntity>[event('new')]),
        throwsStateError,
      );
    });

    expect(store.values[storageKey], raw);
    expect(repository.lastReadCorrupted, isTrue);
  });

  test('serialized concurrent additions retain both events', () async {
    final _MemoryStore store = _MemoryStore();
    final TimelineRepository repository = TimelineRepository(store);

    await Future.wait(<Future<void>>[
      repository.addEvent(event('first')),
      repository.addEvent(event('second')),
    ]);

    expect(
      repository.getEvents().map((item) => item.id),
      containsAll(<String>['first', 'second']),
    );
    expect(repository.getEvents(), hasLength(2));
  });

  test('concurrent lifecycle update cannot erase an added event', () async {
    final _MemoryStore store = _MemoryStore();
    final TimelineRepository repository = TimelineRepository(store);
    await repository.addEvent(event('existing'));

    final Future<void> pendingAdd = repository.addEvent(event('concurrent'));
    TimelineEventEntity? completed;
    final Future<void> pendingCompletion = () async {
      completed = await CompleteTimelineEvent(repository)('existing');
    }();
    await Future.wait<void>(<Future<void>>[pendingAdd, pendingCompletion]);

    expect(completed, isNotNull);
    final List<TimelineEventEntity> events = repository.getEvents();
    expect(events.map((item) => item.id), contains('concurrent'));
    expect(
      events.singleWhere((item) => item.id == 'existing').status,
      TimelineEventStatus.completed,
    );
    expect(events, hasLength(2));
  });
}

class _MemoryStore implements SharedPrefsStore {
  _MemoryStore({this.failingSaveKey});

  final String? failingSaveKey;
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async {
    if (key == failingSaveKey) {
      throw StateError('save failed');
    }
    values[key] = value;
  }

  @override
  String? load(String key) => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}
