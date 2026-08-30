import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/timeline_lifecycle_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _TimelineRepository implements ITimelineRepository {
  @override
  bool get lastReadCorrupted => false;

  List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    events = <TimelineEventEntity>[event, ...events];
  }

  @override
  List<TimelineEventEntity> getEvents() => List<TimelineEventEntity>.of(events);

  @override
  Future<void> removeEvent(String id) async {
    events.removeWhere((TimelineEventEntity event) => event.id == id);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> values) async {
    events = List<TimelineEventEntity>.of(values);
  }
}

TimelineEventEntity _event(DateTime now) => TimelineEventEntity(
  id: 'event-1',
  type: TimelineEventType.task,
  title: 'Write tests',
  detail: 'Complete the lifecycle coverage.',
  timestamp: now,
  dueAt: now.add(const Duration(hours: 1)),
);

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 9);
  late _TimelineRepository repository;

  setUp(() => repository = _TimelineRepository());

  test('schedule and range query persist a planned event', () async {
    final TimelineEventEntity scheduled = await ScheduleTimelineEvent(
      repository,
    )(_event(now));
    final List<TimelineEventEntity> range = QueryTimelineRange(repository)(
      start: now,
      end: now.add(const Duration(days: 1)),
    );

    expect(scheduled.status, TimelineEventStatus.planned);
    expect(range.single.id, scheduled.id);
  });

  test(
    'reschedule, skip, and recover preserve explicit lifecycle state',
    () async {
      await ScheduleTimelineEvent(repository)(_event(now));
      final TimelineEventEntity? rescheduled =
          await RescheduleTimelineEvent(repository)(
            id: 'event-1',
            dueAt: now.add(const Duration(days: 1)),
            now: now.add(const Duration(minutes: 5)),
          );
      final TimelineEventEntity? skipped = await SkipTimelineEvent(repository)(
        'event-1',
        now: now.add(const Duration(minutes: 10)),
      );
      final TimelineEventEntity? recovered =
          await RecoverTimelineEvent(repository)(
            id: 'event-1',
            dueAt: now.add(const Duration(days: 2)),
            now: now.add(const Duration(minutes: 15)),
          );

      expect(rescheduled?.userOverride, isTrue);
      expect(skipped?.status, TimelineEventStatus.skipped);
      expect(recovered?.status, TimelineEventStatus.planned);
      expect(recovered?.phase, 'recovered');
    },
  );

  test('complete returns null for unknown events', () async {
    expect(await CompleteTimelineEvent(repository)('missing'), isNull);
  });
}
