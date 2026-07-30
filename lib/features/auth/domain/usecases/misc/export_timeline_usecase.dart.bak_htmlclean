import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ExportTimelineUsecase {
  const ExportTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  String call() {
    final List<TimelineEventEntity> events = _repository.getEvents();
    return jsonEncode(
      events.map((TimelineEventEntity event) => event.toJson()).toList(),
    );
  }
}
