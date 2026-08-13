import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/completion_event_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs implements SharedPrefsStore {
  _MemoryPrefs({this.failReads = false, this.failWrites = false});

  final Map<String, String> values = <String, String>{};
  final bool failReads;
  final bool failWrites;

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) {
    if (failReads) throw StateError('injected read failure');
    return values[key];
  }

  @override
  Future<void> save(String key, String value) async {
    if (failWrites) throw StateError('injected write failure');
    values[key] = value;
  }
}

final AccountStorageScope _a = AccountStorageScope.authenticated('a/b');
final AccountStorageScope _b = AccountStorageScope.authenticated('a?b');
String _timelineKey(AccountStorageScope scope) =>
    'timeline_events_v2.${scope.v2Namespace}';
String _completionKey(AccountStorageScope scope) =>
    'completion_events_v2.${scope.v2Namespace}';
TimelineRepository _timeline(_MemoryPrefs store, AccountStorageScope scope) =>
    TimelineRepository(store, scope);
CompletionEventRepository _completion(
  _MemoryPrefs store,
  AccountStorageScope scope,
) => CompletionEventRepository(store, scope);
TimelineEventEntity _timelineEvent(String id, String title) =>
    TimelineEventEntity(
      id: id,
      type: TimelineEventType.task,
      title: title,
      detail: title,
      timestamp: DateTime.utc(2026, 8, 13),
    );
CompletionEventEntity _completionEvent(String id, String user) =>
    CompletionEventEntity(
      id: id,
      taskId: 'task-$id',
      userId: user,
      eventType: CompletionEventType.completed,
      eventAt: DateTime.utc(2026, 8, 13),
    );

void main() {
  group('FIX-004A3 Timeline repository scope', () {
    test('TL-01 A persists and reads its event', () async {
      final store = _MemoryPrefs();
      await _timeline(store, _a).addEvent(_timelineEvent('same', 'A'));
      expect(_timeline(store, _a).getEvents().single.title, 'A');
      expect(store.values.containsKey(_timelineKey(_a)), isTrue);
    });
    test('TL-02/TL-03/TL-04 accounts isolate and may share IDs', () async {
      final store = _MemoryPrefs();
      await _timeline(store, _a).addEvent(_timelineEvent('same', 'A'));
      await _timeline(store, _b).addEvent(_timelineEvent('same', 'B'));
      expect(_timeline(store, _a).getEvents().single.title, 'A');
      expect(_timeline(store, _b).getEvents().single.title, 'B');
    });
    test('TL-05 removing A leaves B intact', () async {
      final store = _MemoryPrefs();
      await _timeline(store, _a).addEvent(_timelineEvent('a', 'A'));
      await _timeline(store, _b).addEvent(_timelineEvent('b', 'B'));
      await _timeline(store, _a).removeEvent('a');
      expect(_timeline(store, _a).getEvents(), isEmpty);
      expect(_timeline(store, _b).getEvents().single.title, 'B');
    });
    test(
      'TL-06/TL-07/TL-14 repository recreation preserves each V2 scope',
      () async {
        final store = _MemoryPrefs();
        await _timeline(store, _a).addEvent(_timelineEvent('a', 'A'));
        await _timeline(store, _b).addEvent(_timelineEvent('b', 'B'));
        expect(
          _timeline(
            store,
            AccountStorageScope.authenticated('a/b'),
          ).getEvents().single.title,
          'A',
        );
        expect(
          _timeline(
            store,
            AccountStorageScope.authenticated('a?b'),
          ).getEvents().single.title,
          'B',
        );
      },
    );
    test('TL-08 unsafe scope cannot read or write', () async {
      final store = _MemoryPrefs();
      final TimelineRepository repository = TimelineRepository.unavailable(
        store,
      );
      expect(repository.getEvents, throwsStateError);
      expect(
        () => repository.addEvent(_timelineEvent('x', 'x')),
        throwsStateError,
      );
    });
    test(
      'TL-09/TL-10/TL-11 valid V1 stays invisible and byte-identical',
      () async {
        final store = _MemoryPrefs();
        final String legacy = jsonEncode(<Map<String, dynamic>>[
          _timelineEvent('legacy', 'legacy').toJson(),
        ]);
        store.values['timeline_events_v1'] = legacy;
        expect(_timeline(store, _a).getEvents(), isEmpty);
        expect(_timeline(store, _b).getEvents(), isEmpty);
        expect(store.values['timeline_events_v1'], legacy);
      },
    );
    test('TL-12 scoped read failure never falls back to V1', () {
      final store = _MemoryPrefs(failReads: true)
        ..values['timeline_events_v1'] = 'legacy';
      expect(_timeline(store, _a).getEvents, throwsA(isA<Object>()));
      expect(store.values['timeline_events_v1'], 'legacy');
    });
    test('TL-13 scoped write failure never writes V1', () async {
      final store = _MemoryPrefs(failWrites: true)
        ..values['timeline_events_v1'] = 'legacy';
      await expectLater(
        _timeline(store, _a).addEvent(_timelineEvent('a', 'A')),
        throwsA(isA<Object>()),
      );
      expect(store.values['timeline_events_v1'], 'legacy');
      expect(store.values.containsKey(_timelineKey(_a)), isFalse);
    });
  });

  group('FIX-004A3 Completion repository scope', () {
    test('CE-01 A persists and reads its event', () async {
      final store = _MemoryPrefs();
      await _completion(store, _a).addEvent(_completionEvent('same', 'a/b'));
      expect(_completion(store, _a).getEvents().single.userId, 'a/b');
      expect(store.values.containsKey(_completionKey(_a)), isTrue);
    });
    test('CE-02/CE-03/CE-04 accounts isolate and may share IDs', () async {
      final store = _MemoryPrefs();
      await _completion(store, _a).addEvent(_completionEvent('same', 'a/b'));
      await _completion(store, _b).addEvent(_completionEvent('same', 'a?b'));
      expect(_completion(store, _a).getEvents().single.userId, 'a/b');
      expect(_completion(store, _b).getEvents().single.userId, 'a?b');
    });
    test('CE-05 removing A leaves B intact', () async {
      final store = _MemoryPrefs();
      await _completion(store, _a).addEvent(_completionEvent('a', 'a/b'));
      await _completion(store, _b).addEvent(_completionEvent('b', 'a?b'));
      await _completion(store, _a).removeEvent('a');
      expect(_completion(store, _a).getEvents(), isEmpty);
      expect(_completion(store, _b).getEvents().single.id, 'b');
    });
    test('CE-06/CE-07/CE-14 recreation preserves each V2 scope', () async {
      final store = _MemoryPrefs();
      await _completion(store, _a).addEvent(_completionEvent('a', 'a/b'));
      await _completion(store, _b).addEvent(_completionEvent('b', 'a?b'));
      expect(
        _completion(
          store,
          AccountStorageScope.authenticated('a/b'),
        ).getEvents().single.id,
        'a',
      );
      expect(
        _completion(
          store,
          AccountStorageScope.authenticated('a?b'),
        ).getEvents().single.id,
        'b',
      );
    });
    test('CE-08 unsafe scope cannot read or write', () async {
      final store = _MemoryPrefs();
      final CompletionEventRepository repository =
          CompletionEventRepository.unavailable(store);
      expect(repository.getEvents, throwsStateError);
      expect(
        () => repository.addEvent(_completionEvent('x', 'x')),
        throwsStateError,
      );
    });
    test(
      'CE-09/CE-10/CE-11 valid V1 stays invisible and byte-identical',
      () async {
        final store = _MemoryPrefs();
        final String legacy = jsonEncode(<Map<String, dynamic>>[
          _completionEvent('legacy', 'legacy').toJson(),
        ]);
        store.values['completion_events_v1'] = legacy;
        expect(_completion(store, _a).getEvents(), isEmpty);
        expect(_completion(store, _b).getEvents(), isEmpty);
        expect(store.values['completion_events_v1'], legacy);
      },
    );
    test('CE-12 scoped read failure never falls back to V1', () {
      final store = _MemoryPrefs(failReads: true)
        ..values['completion_events_v1'] = 'legacy';
      expect(_completion(store, _a).getEvents, throwsA(isA<Object>()));
      expect(store.values['completion_events_v1'], 'legacy');
    });
    test('CE-13 scoped write failure never writes V1', () async {
      final store = _MemoryPrefs(failWrites: true)
        ..values['completion_events_v1'] = 'legacy';
      await expectLater(
        _completion(store, _a).addEvent(_completionEvent('a', 'a/b')),
        throwsA(isA<Object>()),
      );
      expect(store.values['completion_events_v1'], 'legacy');
      expect(store.values.containsKey(_completionKey(_a)), isFalse);
    });
  });
}
