import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_insight.dart';
import 'package:fantastic_guacamole/domain/usecases/add_log_entry.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/cancel_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/create_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_flowmap_node.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_insight_from_event.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/get_all_themes.dart';
import 'package:fantastic_guacamole/domain/usecases/get_current_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/get_flowmap_nodes.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/get_insights.dart';
import 'package:fantastic_guacamole/domain/usecases/get_logs.dart';
import 'package:fantastic_guacamole/domain/usecases/get_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/get_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/get_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/get_progression.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/save_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/save_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/save_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/save_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/schedule_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/switch_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/update_flowmap_node.dart';
import 'package:fantastic_guacamole/domain/usecases/update_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/update_level.dart';
import 'package:fantastic_guacamole/domain/usecases/update_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/update_streak.dart';
import 'package:fantastic_guacamole/domain/usecases/update_task.dart';
import 'package:fantastic_guacamole/domain/usecases/update_xp.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final domainTaskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return ref.read(taskRepositoryProvider);
});

final domainNotificationRepositoryProvider = Provider<INotificationRepository>((
  ref,
) {
  return ref.read(notificationsRepositoryProvider);
});

final domainGoalRepositoryProvider = Provider<IGoalRepository>((ref) {
  return ref.read(goalRepositoryProvider);
});

final domainInsightRepositoryProvider = Provider<IInsightRepository>((ref) {
  return ref.read(insightRepositoryProvider);
});

final domainLogRepositoryProvider = Provider<ILogRepository>((ref) {
  return ref.read(logRepositoryProvider);
});

final domainMemoryRepositoryProvider = Provider<IMemoryRepository>((ref) {
  return ref.read(memoryRepositoryProvider);
});

final domainPlanRepositoryProvider = Provider<IPlanRepository>((ref) {
  return ref.read(planRepositoryProvider);
});

final domainProfileRepositoryProvider = Provider<IProfileRepository>((ref) {
  return ref.read(profileRepositoryProvider);
});

final domainProgressionRepositoryProvider = Provider<IProgressionRepository>((
  ref,
) {
  return ref.read(progressionRepositoryProvider);
});

final domainTimelineRepositoryProvider = Provider<ITimelineRepository>((ref) {
  return ref.read(timelineRepositoryProvider);
});

final domainThemeRepositoryProvider = Provider<IThemeRepository>((ref) {
  return ref.read(themeRepositoryProvider);
});

final domainFlowmapRepositoryProvider = Provider<IFlowmapRepository>((ref) {
  return ref.read(flowmapRepositoryProvider);
});

final domainIdentityRepositoryProvider = Provider<IIdentityRepository>((ref) {
  return ref.read(identityRepositoryProvider);
});

final domainSiRepositoryProvider = Provider<ISiRepository>((ref) {
  return _SiRepositoryAdapter(ref);
});

final getTasksUseCaseProvider = Provider<GetTasks>((ref) {
  return GetTasks(ref.read(domainTaskRepositoryProvider));
});

final getGoalsUseCaseProvider = Provider<GetGoals>((ref) {
  return GetGoals(ref.read(domainGoalRepositoryProvider));
});

final getInsightsUseCaseProvider = Provider<GetInsights>((ref) {
  return GetInsights(ref.read(domainInsightRepositoryProvider));
});

final addInsightUseCaseProvider = Provider<AddInsight>((ref) {
  return AddInsight(ref.read(domainInsightRepositoryProvider));
});

final generateInsightFromEventUseCaseProvider =
    Provider<GenerateInsightFromEvent>((ref) {
      return GenerateInsightFromEvent(
        ref.read(domainInsightRepositoryProvider),
      );
    });

final getLogsUseCaseProvider = Provider<GetLogs>((ref) {
  return GetLogs(ref.read(domainLogRepositoryProvider));
});

final addLogEntryUseCaseProvider = Provider<AddLogEntry>((ref) {
  return AddLogEntry(ref.read(domainLogRepositoryProvider));
});

final getCurrentThemeUseCaseProvider = Provider<GetCurrentTheme>((ref) {
  return GetCurrentTheme(ref.read(domainThemeRepositoryProvider));
});

final saveThemeUseCaseProvider = Provider<SaveTheme>((ref) {
  return SaveTheme(ref.read(domainThemeRepositoryProvider));
});

final getAllThemesUseCaseProvider = Provider<GetAllThemes>((ref) {
  return GetAllThemes(ref.read(domainThemeRepositoryProvider));
});

final switchThemeUseCaseProvider = Provider<SwitchTheme>((ref) {
  return SwitchTheme(ref.read(domainThemeRepositoryProvider));
});

final getIdentityProfileUseCaseProvider = Provider<GetIdentityProfile>((ref) {
  return GetIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final saveIdentityProfileUseCaseProvider = Provider<SaveIdentityProfile>((ref) {
  return SaveIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final createGoalUseCaseProvider = Provider<CreateGoal>((ref) {
  return CreateGoal(ref.read(domainGoalRepositoryProvider));
});

final updateGoalUseCaseProvider = Provider<UpdateGoal>((ref) {
  return UpdateGoal(ref.read(domainGoalRepositoryProvider));
});

final deleteGoalUseCaseProvider = Provider<DeleteGoal>((ref) {
  return DeleteGoal(ref.read(domainGoalRepositoryProvider));
});

final completeGoalUseCaseProvider = Provider<CompleteGoal>((ref) {
  return CompleteGoal(ref.read(domainGoalRepositoryProvider));
});

final saveGoalsUseCaseProvider = Provider<SaveGoals>((ref) {
  return SaveGoals(ref.read(domainGoalRepositoryProvider));
});

final getMemoriesUseCaseProvider = Provider<GetMemories>((ref) {
  return GetMemories(ref.read(domainMemoryRepositoryProvider));
});

final saveMemoryUseCaseProvider = Provider<SaveMemory>((ref) {
  return SaveMemory(ref.read(domainMemoryRepositoryProvider));
});

final deleteMemoryUseCaseProvider = Provider<DeleteMemory>((ref) {
  return DeleteMemory(ref.read(domainMemoryRepositoryProvider));
});

final saveMemoriesUseCaseProvider = Provider<SaveMemories>((ref) {
  return SaveMemories(ref.read(domainMemoryRepositoryProvider));
});

final getPlanUseCaseProvider = Provider<GetPlan>((ref) {
  return GetPlan(ref.read(domainPlanRepositoryProvider));
});

final createPlanUseCaseProvider = Provider<CreatePlan>((ref) {
  return CreatePlan(ref.read(domainPlanRepositoryProvider));
});

final updatePlanUseCaseProvider = Provider<UpdatePlan>((ref) {
  return UpdatePlan(ref.read(domainPlanRepositoryProvider));
});

final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  return GetProfile(ref.read(domainProfileRepositoryProvider));
});

final getProgressionUseCaseProvider = Provider<GetProgression>((ref) {
  return GetProgression(ref.read(domainProgressionRepositoryProvider));
});

final updateStreakUseCaseProvider = Provider<UpdateStreak>((ref) {
  return UpdateStreak(ref.read(domainProgressionRepositoryProvider));
});

final updateXpUseCaseProvider = Provider<UpdateXp>((ref) {
  return UpdateXp(ref.read(domainProgressionRepositoryProvider));
});

final updateLevelUseCaseProvider = Provider<UpdateLevel>((ref) {
  return UpdateLevel(ref.read(domainProgressionRepositoryProvider));
});

final getTimelineEventsUseCaseProvider = Provider<GetTimelineEvents>((ref) {
  return GetTimelineEvents(ref.read(domainTimelineRepositoryProvider));
});

final addTimelineEventUseCaseProvider = Provider<AddTimelineEvent>((ref) {
  return AddTimelineEvent(ref.read(domainTimelineRepositoryProvider));
});

final removeTimelineEventUseCaseProvider = Provider<RemoveTimelineEvent>((ref) {
  return RemoveTimelineEvent(ref.read(domainTimelineRepositoryProvider));
});

final saveTimelineEventsUseCaseProvider = Provider<SaveTimelineEvents>((ref) {
  return SaveTimelineEvents(ref.read(domainTimelineRepositoryProvider));
});

final getFlowmapUseCaseProvider = Provider<GetFlowmap>((ref) {
  return GetFlowmap(ref.read(domainFlowmapRepositoryProvider));
});

final updateFlowmapNodeUseCaseProvider = Provider<UpdateFlowmapNode>((ref) {
  return UpdateFlowmapNode(ref.read(domainFlowmapRepositoryProvider));
});

final deleteFlowmapNodeUseCaseProvider = Provider<DeleteFlowmapNode>((ref) {
  return DeleteFlowmapNode(ref.read(domainFlowmapRepositoryProvider));
});

final createTaskUseCaseProvider = Provider<CreateTask>((ref) {
  return CreateTask(
    ref.read(domainTaskRepositoryProvider),
    generateSiDecision: ref.read(generateSiDecisionUseCaseProvider),
  );
});

final completeTaskUseCaseProvider = Provider<CompleteTask>((ref) {
  return CompleteTask(ref.read(domainTaskRepositoryProvider));
});

final updateTaskUseCaseProvider = Provider<UpdateTask>((ref) {
  return UpdateTask(ref.read(domainTaskRepositoryProvider));
});

final deleteTaskUseCaseProvider = Provider<DeleteTask>((ref) {
  return DeleteTask(ref.read(domainTaskRepositoryProvider));
});

final scheduleNotificationUseCaseProvider = Provider<ScheduleNotification>((
  ref,
) {
  return ScheduleNotification(ref.read(domainNotificationRepositoryProvider));
});

final cancelNotificationUseCaseProvider = Provider<CancelNotification>((ref) {
  return CancelNotification(ref.read(domainNotificationRepositoryProvider));
});

final generateSiDecisionUseCaseProvider = Provider<GenerateSiDecision>((ref) {
  return GenerateSiDecision(
    ref.read(domainTaskRepositoryProvider),
    ref.read(domainSiRepositoryProvider),
  );
});

final domainSiDecisionProvider = FutureProvider<Task?>((ref) async {
  final SiDecisionEntity decision = await ref
      .read(generateSiDecisionUseCaseProvider)
      .call();
  final String? selectedTaskId = decision.selectedTaskId;
  if (selectedTaskId == null || selectedTaskId.isEmpty) {
    return null;
  }

  final TaskEntity? task = await ref
      .read(domainTaskRepositoryProvider)
      .getTaskById(selectedTaskId);
  return task == null ? null : _taskFromEntity(task);
});

Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
  );
}

class _SiRepositoryAdapter implements ISiRepository {
  _SiRepositoryAdapter(this._ref);

  final Ref _ref;

  @override
  Future<SiStateEntity?> getCurrentState() async {
    final SIState state = _ref.read(siStateProvider);
    return SiStateEntity(
      energy: state.energy,
      focus: (state.energy * (1 - state.fatigue)).clamp(0.0, 1.0),
      fatigue: state.fatigue,
    );
  }

  @override
  Future<void> saveState(SiStateEntity state) async {
    _ref
        .read(siStateProvider.notifier)
        .replaceState(energy: state.energy, fatigue: state.fatigue);
  }
}
