import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ShareTimelineUsecase {
  const ShareTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  String call({int limit = 10}) {
    final List<TimelineEventEntity> events =
        <TimelineEventEntity>[..._repository.getEvents()]..sort(
          (TimelineEventEntity a, TimelineEventEntity b) =>
              b.timestamp.compareTo(a.timestamp),
        );

    if (events.isEmpty) {
      return 'ChronoSpark timeline has no events yet.';
    }

    final Iterable<TimelineEventEntity> selected = events.take(limit);
    final StringBuffer buffer = StringBuffer('ChronoSpark Timeline Summary\n');

    for (final TimelineEventEntity event in selected) {
      buffer.writeln('- ${event.shortLabel}: ${event.title}');
    }

    return buffer.toString().trim();
  }
}
