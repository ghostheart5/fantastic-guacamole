import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineWarning {
  const TimelineWarning({
    required this.title,
    required this.detail,
    this.relatedEvent,
  });

  final String title;
  final String detail;
  final TimelineEventEntity? relatedEvent;
}

class SurfaceTimelineWarningsUsecase {
  const SurfaceTimelineWarningsUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineWarning> call() {
    final List<TimelineEventEntity> events = _repository.getEvents();
    final List<TimelineWarning> warnings = <TimelineWarning>[];

    for (final TimelineEventEntity event in events) {
      if (event.isOverdue) {
        warnings.add(
          TimelineWarning(
            title: 'Overdue timeline item',
            detail: event.title,
            relatedEvent: event,
          ),
        );
      }

      if (event.isRisk) {
        warnings.add(
          TimelineWarning(
            title: 'Timeline risk detected',
            detail: event.title,
            relatedEvent: event,
          ),
        );
      }
    }

    return warnings;
  }
}
