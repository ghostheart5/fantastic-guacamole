import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/completion_event_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;

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

final AccountStorageScope _a = AccountStorageScope.authenticated('account-a');
final AccountStorageScope _b = AccountStorageScope.authenticated('account-b');

TimelineEventEntity _timeline(String id, String title) => TimelineEventEntity(
  id: id,
  type: TimelineEventType.task,
  title: title,
  detail: title,
  timestamp: DateTime.utc(2026, 8, 13),
);

CompletionEventEntity _completion(String id, String userId) =>
    CompletionEventEntity(
      id: id,
      taskId: 'task-$id',
      userId: userId,
      eventType: CompletionEventType.completed,
      eventAt: DateTime.utc(2026, 8, 13),
    );

void main() {
  group('PRE-TEST-02D Timeline failure safety', () {
    test('FI-TL-01 scoped read failure does not read V1', () {
      final _FailingPrefs store = _FailingPrefs()
        ..values['timeline_events_v1'] = 'legacy'
        ..failReads = true;
      expect(
        () => TimelineRepository(store, _a).getEvents(),
        throwsA(isA<Object>()),
      );
      expect(store.values['timeline_events_v1'], 'legacy');
    });

    test('FI-TL-02 failed scoped write preserves prior scope and V1', () async {
      final _FailingPrefs store = _FailingPrefs()
        ..values['timeline_events_v1'] = 'legacy';
      await TimelineRepository(store, _a).addEvent(_timeline('a0', 'A0'));
      final String before =
          store.values['timeline_events_v2.${_a.v2Namespace}']!;
      store.failWrites = true;
      await expectLater(
        TimelineRepository(store, _a).addEvent(_timeline('a1', 'A1')),
        throwsA(isA<Object>()),
      );
      expect(store.values['timeline_events_v2.${_a.v2Namespace}'], before);
      expect(store.values['timeline_events_v1'], 'legacy');
      expect(store.values['timeline_events_v2.${_b.v2Namespace}'], isNull);
    });

    test(
      'FI-TL-03/FI-TL-04 failure then B transition and retry stay scoped',
      () async {
        final _FailingPrefs store = _FailingPrefs();
        await TimelineRepository(store, _a).addEvent(_timeline('a', 'A'));
        store.failWrites = true;
        await expectLater(
          TimelineRepository(store, _a).addEvent(_timeline('failed', 'failed')),
          throwsA(isA<Object>()),
        );
        store.failWrites = false;
        final TimelineRepository b = TimelineRepository(store, _b);
        expect(b.getEvents(), isEmpty);
        await b.addEvent(_timeline('b', 'B'));
        final TimelineRepository rebuiltA = TimelineRepository(store, _a);
        expect(rebuiltA.getEvents().map((event) => event.id), <String>['a']);
        expect(b.getEvents().map((event) => event.id), <String>['b']);
      },
    );
  });

  group('PRE-TEST-02D Completion failure safety', () {
    test('FI-CE-01 scoped read failure does not read V1', () {
      final _FailingPrefs store = _FailingPrefs()
        ..values['completion_events_v1'] = 'legacy'
        ..failReads = true;
      expect(
        () => CompletionEventRepository(store, _a).getEvents(),
        throwsA(isA<Object>()),
      );
      expect(store.values['completion_events_v1'], 'legacy');
    });

    test('FI-CE-02 failed scoped write preserves prior scope and V1', () async {
      final _FailingPrefs store = _FailingPrefs()
        ..values['completion_events_v1'] = 'legacy';
      await CompletionEventRepository(
        store,
        _a,
      ).addEvent(_completion('a0', 'a'));
      final String before =
          store.values['completion_events_v2.${_a.v2Namespace}']!;
      store.failWrites = true;
      await expectLater(
        CompletionEventRepository(store, _a).addEvent(_completion('a1', 'a')),
        throwsA(isA<Object>()),
      );
      expect(store.values['completion_events_v2.${_a.v2Namespace}'], before);
      expect(store.values['completion_events_v1'], 'legacy');
      expect(store.values['completion_events_v2.${_b.v2Namespace}'], isNull);
    });

    test(
      'FI-CE-03/FI-CE-04 failure then B transition and retry stay scoped',
      () async {
        final _FailingPrefs store = _FailingPrefs();
        await CompletionEventRepository(
          store,
          _a,
        ).addEvent(_completion('a', 'a'));
        store.failWrites = true;
        await expectLater(
          CompletionEventRepository(
            store,
            _a,
          ).addEvent(_completion('failed', 'a')),
          throwsStateError,
        );
        store.failWrites = false;
        final CompletionEventRepository b = CompletionEventRepository(
          store,
          _b,
        );
        expect(b.getEvents(), isEmpty);
        await b.addEvent(_completion('b', 'b'));
        expect(
          CompletionEventRepository(
            store,
            _a,
          ).getEvents().map((event) => event.id),
          <String>['a'],
        );
        expect(b.getEvents().map((event) => event.id), <String>['b']);
      },
    );
  });
}
