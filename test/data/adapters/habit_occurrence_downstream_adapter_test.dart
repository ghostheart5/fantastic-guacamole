import 'package:fantastic_guacamole/data/adapters/habit_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/habit_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_reminder_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timeline implements ITimelineRepository {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];
  bool failNextAdd = false;
  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('timeline failure');
    }
    events.add(event);
  }

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.from(events);
  @override
  Future<void> removeEvent(String id) async =>
      events.removeWhere((TimelineEventEntity event) => event.id == id);
  @override
  Future<void> saveEvents(List<TimelineEventEntity> values) async {
    events
      ..clear()
      ..addAll(values);
  }
}

class _Queue implements SyncQueueStoreContract {
  final List<SyncOperation> values = <SyncOperation>[];
  @override
  Future<void> enqueue(SyncOperation operation) async => values.add(operation);
  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    values
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async =>
      List<SyncOperation>.from(values);
  @override
  Future<void> removeById(String id) async =>
      values.removeWhere((SyncOperation item) => item.operationId == id);
  @override
  Future<void> update(SyncOperation updated) async {
    await overwrite(
      values
          .map(
            (SyncOperation item) =>
                item.operationId == updated.operationId ? updated : item,
          )
          .toList(),
    );
  }
}

HabitOccurrence _occurrence(HabitOccurrenceStatus status) => HabitOccurrence(
  habitId: 'same',
  periodKey: '2026-08-15',
  ordinal: 1,
  status: status,
  completedAt: status == HabitOccurrenceStatus.completed
      ? DateTime.utc(2026, 8, 15)
      : null,
  skippedAt: status == HabitOccurrenceStatus.skipped
      ? DateTime.utc(2026, 8, 15)
      : null,
);

void main() {
  test(
    'Timeline projects completed and skipped occurrences idempotently and retries deterministically',
    () async {
      final _Timeline timeline = _Timeline();
      final HabitOccurrenceTimelineAdapter adapter =
          HabitOccurrenceTimelineAdapter(timeline);
      final HabitOccurrence completed = _occurrence(
        HabitOccurrenceStatus.completed,
      );
      await adapter.record(completed);
      await adapter.record(completed);
      expect(timeline.events, hasLength(1));
      expect(timeline.events.single.type, TimelineEventType.habitCompleted);
      expect(
        timeline.events.single.id,
        'habit-occurrence:${completed.id}:completed',
      );
      final HabitOccurrence skipped = _occurrence(
        HabitOccurrenceStatus.skipped,
      );
      timeline.failNextAdd = true;
      await expectLater(adapter.record(skipped), throwsStateError);
      expect(timeline.events, hasLength(1));
      await adapter.record(skipped);
      expect(timeline.events, hasLength(2));
      expect(timeline.events.last.type, TimelineEventType.habitSkipped);
    },
  );

  test(
    'Sync uses canonical occurrence identity and existing queue replacement dedupe',
    () async {
      final _Queue queue = _Queue();
      final HabitOccurrenceSyncAdapter adapter = HabitOccurrenceSyncAdapter(
        SyncMutationDispatcher(
          queueStore: queue,
          userId: 'account-a',
          isAuthorized: () => true,
        ),
      );
      final HabitOccurrence occurrence = _occurrence(
        HabitOccurrenceStatus.completed,
      );
      await adapter.enqueue(occurrence);
      await adapter.enqueue(occurrence);
      expect(queue.values, hasLength(1));
      final SyncOperation operation = queue.values.single;
      expect(operation.tableName, 'habit_occurrences');
      expect(operation.recordId, occurrence.id);
      expect(operation.payload['status'], 'completed');
    },
  );

  test(
    'Reminder adapter is intentionally a safe no-op for resolved occurrences',
    () async {
      await const HabitOccurrenceReminderAdapter().reconcile(
        _occurrence(HabitOccurrenceStatus.skipped),
      );
    },
  );
}
