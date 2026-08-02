import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_connection_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class ConnectTimelineToProjectsUsecase {
  const ConnectTimelineToProjectsUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<ProjectTimelineLink> call(ProjectEntity project) async {
    final DateTime now = DateTime.now();
    final String eventId =
        'project_link_${project.id}_${now.microsecondsSinceEpoch}';

    final TimelineEventEntity event = TimelineEventEntity(
      id: eventId,
      type: TimelineEventType.project,
      title: project.name.trim().isEmpty
          ? 'Project linked'
          : project.name.trim(),
      detail: (project.description ?? 'Project connected to timeline.').trim(),
      timestamp: now,
      status: project.archived
          ? TimelineEventStatus.completed
          : TimelineEventStatus.active,
      relatedId: project.id,
    );

    await AddTimelineEvent(_repository).call(event);

    return ProjectTimelineLink(
      id: 'project_timeline_link_${project.id}_${now.microsecondsSinceEpoch}',
      timelineEventId: eventId,
      targetId: project.id,
      createdAt: now,
      label: event.title,
    );
  }
}
