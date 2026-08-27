import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class QueryTimelineRange {
  const QueryTimelineRange(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call({
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) return const <TimelineEventEntity>[];
    final List<TimelineEventEntity> events = _repository
        .getEvents()
        .where((TimelineEventEntity event) {
          final DateTime anchor = event.dueAt ?? event.timestamp;
          return !anchor.isBefore(start) && anchor.isBefore(end);
        })
        .toList(growable: false);
    events.sort((TimelineEventEntity first, TimelineEventEntity second) {
      return (first.dueAt ?? first.timestamp).compareTo(
        second.dueAt ?? second.timestamp,
      );
    });
    return events;
  }
}

class ScheduleTimelineEvent {
  const ScheduleTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<TimelineEventEntity> call(TimelineEventEntity event) async {
    final TimelineEventEntity scheduled = event.copyWith(
      status: TimelineEventStatus.planned,
    );
    scheduled.validate();
    await _repository.addEvent(scheduled);
    return scheduled;
  }
}

class RescheduleTimelineEvent {
  const RescheduleTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<TimelineEventEntity?> call({
    required String id,
    required DateTime dueAt,
    DateTime? now,
  }) {
    return _replace(
      id,
      (TimelineEventEntity event) => event.copyWith(
        dueAt: dueAt,
        timestamp: now ?? DateTime.now(),
        status: TimelineEventStatus.planned,
        phase: 'rescheduled',
        userOverride: true,
      ),
    );
  }

  Future<TimelineEventEntity?> _replace(
    String id,
    TimelineEventEntity Function(TimelineEventEntity) transform,
  ) async {
    final List<TimelineEventEntity> current = _repository.getEvents();
    final int index = current.indexWhere(
      (TimelineEventEntity event) => event.id == id,
    );
    if (index < 0) return null;
    final TimelineEventEntity updated = transform(current[index]);
    final List<TimelineEventEntity> next = current.toList(growable: true);
    next[index] = updated;
    await _repository.saveEvents(next);
    return updated;
  }
}

class CompleteTimelineEvent {
  const CompleteTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<TimelineEventEntity?> call(String id, {DateTime? now}) {
    return _updateTimelineStatus(
      repository: _repository,
      id: id,
      status: TimelineEventStatus.completed,
      phase: 'completed',
      now: now,
    );
  }
}

class SkipTimelineEvent {
  const SkipTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<TimelineEventEntity?> call(String id, {DateTime? now}) {
    return _updateTimelineStatus(
      repository: _repository,
      id: id,
      status: TimelineEventStatus.skipped,
      phase: 'skipped',
      now: now,
    );
  }
}

class RecoverTimelineEvent {
  const RecoverTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<TimelineEventEntity?> call({
    required String id,
    required DateTime dueAt,
    DateTime? now,
  }) async {
    final List<TimelineEventEntity> current = _repository.getEvents();
    final int index = current.indexWhere(
      (TimelineEventEntity event) => event.id == id,
    );
    if (index < 0) return null;
    final TimelineEventEntity recovered = current[index].copyWith(
      dueAt: dueAt,
      timestamp: now ?? DateTime.now(),
      status: TimelineEventStatus.planned,
      phase: 'recovered',
      userOverride: true,
    );
    final List<TimelineEventEntity> next = current.toList(growable: true);
    next[index] = recovered;
    await _repository.saveEvents(next);
    return recovered;
  }
}

Future<TimelineEventEntity?> _updateTimelineStatus({
  required ITimelineRepository repository,
  required String id,
  required TimelineEventStatus status,
  required String phase,
  DateTime? now,
}) async {
  final List<TimelineEventEntity> current = repository.getEvents();
  final int index = current.indexWhere(
    (TimelineEventEntity event) => event.id == id,
  );
  if (index < 0) return null;
  final TimelineEventEntity updated = current[index].copyWith(
    timestamp: now ?? DateTime.now(),
    status: status,
    phase: phase,
    userOverride: true,
  );
  final List<TimelineEventEntity> next = current.toList(growable: true);
  next[index] = updated;
  await repository.saveEvents(next);
  return updated;
}
