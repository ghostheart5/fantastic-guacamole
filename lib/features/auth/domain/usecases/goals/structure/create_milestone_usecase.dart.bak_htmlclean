import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class CreateMilestoneUsecase {
  const CreateMilestoneUsecase(this._goalRepository, this._timelineRepository);

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call({
    required String goalId,
    required String title,
    String? detail,
    DateTime? dueAt,
    DateTime? timestamp,
  }) async {
    final String targetGoalId = goalId.trim();
    if (targetGoalId.isEmpty) {
      return null;
    }

    GoalEntity? goal;
    for (final GoalEntity item in _goalRepository.getGoals()) {
      if (item.id == targetGoalId) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    final DateTime now = timestamp ?? DateTime.now();
    final TimelineEventEntity milestone = TimelineEventEntity(
      id: 'goal_milestone_${targetGoalId}_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.milestone,
      title: title.trim().isEmpty ? 'Goal milestone' : title.trim(),
      detail: detail?.trim().isEmpty ?? true
          ? 'Milestone for ${goal.title}'
          : detail!.trim(),
      timestamp: now,
      status: TimelineEventStatus.planned,
      dueAt: dueAt,
      phase: 'milestone',
      relatedId: targetGoalId,
    );

    await _timelineRepository.addEvent(milestone);
    return milestone;
  }
}
