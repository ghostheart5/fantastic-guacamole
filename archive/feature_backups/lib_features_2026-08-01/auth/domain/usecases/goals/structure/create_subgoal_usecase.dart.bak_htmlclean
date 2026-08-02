import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class CreateSubgoalUsecase {
  const CreateSubgoalUsecase(this._goalRepository, this._timelineRepository);

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call({
    required String goalId,
    required String title,
    String? detail,
    DateTime? dueAt,
  }) async {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? goal;

    for (final GoalEntity item in _goalRepository.getGoals()) {
      if (item.id == targetId) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    final DateTime now = DateTime.now();

    final TimelineEventEntity subgoal = TimelineEventEntity(
      id: 'goal_subgoal_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.goal,
      title: title.trim().isEmpty ? 'Subgoal' : title.trim(),
      detail: detail?.trim().isEmpty ?? true
          ? 'Subgoal for ${goal.title}'
          : detail!.trim(),
      timestamp: now,
      status: TimelineEventStatus.planned,
      dueAt: dueAt,
      phase: 'subgoal',
      relatedId: targetId,
    );

    await _timelineRepository.addEvent(subgoal);

    return subgoal;
  }
}
