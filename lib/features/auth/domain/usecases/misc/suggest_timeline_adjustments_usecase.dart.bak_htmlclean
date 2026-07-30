import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineAdjustment {
  const TimelineAdjustment({
    required this.title,
    required this.detail,
    this.relatedEvent,
  });

  final String title;
  final String detail;
  final TimelineEventEntity? relatedEvent;
}

class SuggestTimelineAdjustmentsUsecase {
  const SuggestTimelineAdjustmentsUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineAdjustment> call() {
    final List<TimelineEventEntity> events = _repository.getEvents();
    final List<TimelineAdjustment> adjustments = <TimelineAdjustment>[];

    final List<TimelineEventEntity> overdue = events
        .where((TimelineEventEntity event) => event.isOverdue)
        .toList(growable: false);

    final List<TimelineEventEntity> risks = events
        .where((TimelineEventEntity event) => event.isRisk)
        .toList(growable: false);

    if (overdue.isNotEmpty) {
      adjustments.add(
        TimelineAdjustment(
          title: 'Recover overdue item',
          detail:
              'Move the most overdue item into today or split the work into a smaller next step.',
          relatedEvent: overdue.first,
        ),
      );
    }

    if (risks.isNotEmpty) {
      adjustments.add(
        TimelineAdjustment(
          title: 'Reduce timeline risk',
          detail:
              'Review the highest risk item and reduce scope, delay, or reprioritize it.',
          relatedEvent: risks.first,
        ),
      );
    }

    if (adjustments.isEmpty) {
      adjustments.add(
        const TimelineAdjustment(
          title: 'Maintain current trajectory',
          detail: 'Timeline has no urgent adjustment signals right now.',
        ),
      );
    }

    return adjustments;
  }
}
