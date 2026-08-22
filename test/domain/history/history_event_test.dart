import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/history/history_event.dart';
import 'package:fantastic_guacamole/domain/history/timeline_history_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryEvent', () {
    test('round-trips typed facts with UTC time, linkage, and provenance', () {
      final HistoryEvent event = HistoryEvent(
        id: 'history-1',
        kind: HistoryEventKind.taskCompleted,
        occurredAt: DateTime.parse('2026-08-12T18:30:00-05:00'),
        entityType: HistoryEntityType.task,
        entityId: 'task-1',
        source: HistoryEventSource.creator,
        payload: const <String, dynamic>{'quality': 0.8},
      );

      final HistoryEvent decoded = HistoryEvent.fromJson(event.toJson());
      expect(decoded.kind, HistoryEventKind.taskCompleted);
      expect(decoded.occurredAt, DateTime.utc(2026, 8, 12, 23, 30));
      expect(decoded.entityType, HistoryEntityType.task);
      expect(decoded.entityId, 'task-1');
      expect(decoded.source, HistoryEventSource.creator);
      expect(decoded.payload['quality'], 0.8);
    });

    test('preserves unknown legacy Timeline kinds explicitly', () {
      final HistoryEvent event =
          TimelineHistoryAdapter.fromLegacyJson(<String, dynamic>{
            'id': 'legacy-1',
            'type': 'future_custom_kind',
            'title': 'Imported item',
            'detail': 'Keep this record.',
            'timestamp': '2026-08-12T12:00:00.000Z',
            'status': 'info',
          });

      expect(event.kind, HistoryEventKind.legacyTimeline);
      expect(event.legacyKind, 'future_custom_kind');
      expect(event.payload['legacyTimeline'], isA<Map<String, dynamic>>());
    });
  });

  group('Timeline history compatibility', () {
    test(
      'adapts known creator completion facts without changing Timeline UI data',
      () {
        final TimelineEventEntity timeline = TimelineEventEntity(
          id: 'timeline-complete',
          type: TimelineEventType.reflection,
          title: 'Task Completed',
          detail: 'Write history contract marked complete.',
          timestamp: DateTime.utc(2026, 8, 12, 15),
          relatedId: 'task-2',
        );

        final HistoryEvent history = TimelineHistoryAdapter.fromLegacyJson(
          timeline.toJson(),
        );
        final TimelineEventEntity restored = TimelineHistoryAdapter.toTimeline(
          history,
        );

        expect(history.kind, HistoryEventKind.taskCompleted);
        expect(history.entityId, 'task-2');
        expect(restored.type, TimelineEventType.reflection);
        expect(restored.title, timeline.title);
        expect(restored.detail, timeline.detail);
      },
    );

    test(
      'repository writes scoped canonical records and orders history',
      () async {
        final _MemoryStore store = _MemoryStore();
        final AccountStorageScope scope = AccountStorageScope.authenticated(
          'history-test',
        );
        final TimelineRepository repository = TimelineRepository(store, scope);
        final String key = 'timeline_events_v2.${scope.v2Namespace}';
        await repository.saveEvents(<TimelineEventEntity>[
          TimelineEventEntity(
            id: 'older',
            type: TimelineEventType.task,
            title: 'Older task',
            detail: 'Scheduled earlier.',
            timestamp: DateTime.utc(2026, 8, 10),
          ),
          TimelineEventEntity(
            id: 'newer',
            type: TimelineEventType.goalComplete,
            title: 'Newer goal',
            detail: 'Completed later.',
            timestamp: DateTime.utc(2026, 8, 12),
            relatedId: 'goal-1',
          ),
        ]);

        final List<dynamic> persisted =
            jsonDecode(store.values[key]!) as List<dynamic>;
        expect((persisted.first as Map<String, dynamic>)['schemaVersion'], 1);
        expect(repository.getHistoryEvents().first.id, 'newer');

        store.values[key] = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy',
            'type': 'reflection',
            'title': 'Legacy reflection',
            'detail': 'Old shape remains readable.',
            'timestamp': '2026-08-11T00:00:00.000Z',
            'status': 'info',
          },
        ]);
        expect(repository.getEvents().single.title, 'Legacy reflection');
        expect(
          repository.getHistoryEvents().single.kind,
          HistoryEventKind.reflectionRecorded,
        );
      },
    );
  });
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }
}
