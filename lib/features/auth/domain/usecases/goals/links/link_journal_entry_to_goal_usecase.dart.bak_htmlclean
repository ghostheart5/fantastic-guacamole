import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class LinkJournalEntryToGoalUsecase {
  const LinkJournalEntryToGoalUsecase(
    this._goalRepository,
    this._timelineRepository,
  );

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call({
    required String goalId,
    required String journalEntryId,
  }) async {
    final String targetGoalId = goalId.trim();
    final String targetItemId = journalEntryId.trim();

    if (targetGoalId.isEmpty || targetItemId.isEmpty) {
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

    final DateTime now = DateTime.now();

    final TimelineEventEntity event = TimelineEventEntity(
      id: 'goal.link.journal${targetGoalId}_${targetItemId}_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.reflection,
      title: 'Journal entry linked to goal',
      detail: 'Journal entry linked $targetItemId for goal "${goal.title}".',
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'goal.link.journal',
      relatedId: targetGoalId,
    );

    await _timelineRepository.addEvent(event);

    return event;
  }
}
