import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineConflict {
  const TimelineConflict({
    required this.first,
    required this.second,
    required this.reason,
  });

  final TimelineEventEntity first;
  final TimelineEventEntity second;
  final String reason;
}

class DetectTimelineConflictUsecase {
  const DetectTimelineConflictUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineConflict> call() {
    final List<TimelineEventEntity> events = _repository.getEvents();
    final List<TimelineConflict> conflicts = <TimelineConflict>[];

    for (int i = 0; i < events.length; i++) {
      for (int j = i + 1; j < events.length; j++) {
        final TimelineEventEntity first = events[i];
        final TimelineEventEntity second = events[j];

        final DateTime? firstDue = first.dueAt;
        final DateTime? secondDue = second.dueAt;

        if (firstDue == null || secondDue == null) {
          continue;
        }

        final bool sameDay =
            firstDue.year == secondDue.year &&
            firstDue.month == secondDue.month &&
            firstDue.day == secondDue.day;

        if (sameDay &&
            first.status != TimelineEventStatus.completed &&
            second.status != TimelineEventStatus.completed) {
          conflicts.add(
            TimelineConflict(
              first: first,
              second: second,
              reason: 'Multiple active timeline items share the same due date.',
            ),
          );
        }
      }
    }

    return conflicts;
  }
}
