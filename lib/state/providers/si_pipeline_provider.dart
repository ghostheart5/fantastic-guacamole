import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/usecases/assemble_si_decision_output.dart';
import 'package:fantastic_guacamole/domain/usecases/extract_si_signals.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siStateAggregationProvider = FutureProvider<SIStateAggregation>((
  Ref ref,
) async {
  final List<TaskEntity> taskEntities = await _loadAllActiveTaskEntities(ref);
  final List<PlannerInput> plannerInputs = PlannerInputAdapter.fromTaskEntities(
    taskEntities,
  );
  final List<Task> tasks = PlannerInputAdapter.toLegacyTasks(plannerInputs);
  final goals = ref.watch(goalsProvider);
  final signalBundle = ref.watch(signalsBundleProvider);
  final logs = ref.watch(logsProvider).entries;
  final timeline = ref.watch(timelineProvider);
  final memories = ref.watch(memoriesProvider);
  final notifications = ref.watch(notificationProvider);
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final EmotionalState emotion = ref.watch(emotionProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final double energy = ref.watch(energyProvider);
  final DateTime observedAt = DateTime.now();
  // Habits feed Smart Planner and SI. Read non-blocking: if habit storage has
  // not resolved (or failed), aggregation continues with none rather than
  // stalling the whole SI pipeline on it.
  final AsyncValue<List<HabitEntity>> habitsAsync = ref.watch(habitsProvider);
  final SISourceStatus habitsHealth = habitsAsync.isLoading
      ? SISourceStatus.loading
      : habitsAsync.hasError
      ? SISourceStatus.error
      : (habitsAsync.asData?.value.isEmpty ?? true)
      ? SISourceStatus.empty
      : SISourceStatus.ready;
  final List<HabitEntity> habits = habitsAsync.maybeWhen(
    data: (List<HabitEntity> value) => value,
    orElse: () => const <HabitEntity>[],
  );

  final List<String> planPreview = ref
      .read(generateAdaptivePlanUseCaseProvider)
      .call(inputs: plannerInputs, energy: energy)
      .take(3)
      .map((block) => block.title)
      .toList(growable: false);

  int countToday(Set<String> sources) => logs
      .where(
        (entry) =>
            sources.contains(entry.source.trim().toLowerCase()) &&
            entry.timestamp.year == observedAt.year &&
            entry.timestamp.month == observedAt.month &&
            entry.timestamp.day == observedAt.day,
      )
      .length;

  // Signal thresholds live in the domain layer so this provider orchestrates
  // rather than owning core SI logic.
  final SiSignals planningSignals = ref
      .read(extractSiSignalsUseCaseProvider)
      .call(
        pressureIndex: trajectory.pressureIndex.toDouble(),
        behaviorDivergence: trajectory.behaviorDivergence.toDouble(),
        energy: energy,
        streak: profile.streak,
        hasGoals: goals.isNotEmpty,
        skippedTaskCount: logs
            .where((entry) => entry.source == 'task_skipped')
            .length,
        emotion: emotion.name,
        signalsSummary: signalBundle.summary,
      );

  LearningEntity learning = const LearningEntity();
  SISourceStatus learningHealth = SISourceStatus.empty;
  try {
    final LearningEntity? storedLearning = await ref
        .read(domainLearningRepositoryProvider)
        .getState();
    if (storedLearning != null) {
      learning = storedLearning;
      learningHealth = SISourceStatus.ready;
    }
  } on Object {
    learningHealth = SISourceStatus.error;
  }
  final DecisionRecommendation planningDecision = const DecisionEngine()
      .recommend(
        inputs: plannerInputs,
        state: SiStateEntity(
          energy: siState.energy,
          attention: (1 - siState.fatigue).clamp(0.0, 1.0),
          fatigue: siState.fatigue,
          mood: emotion.name,
          avoidOverwhelm: planningSignals.overwhelm,
          frictionScore: planningSignals.friction ? .8 : .2,
          highFriction: planningSignals.friction,
          lastUpdated: observedAt,
        ),
        learning: learning,
        now: observedAt,
      );

  return SIStateAggregation(
    tasks: tasks,
    goals: goals,
    signals: signalBundle,
    logs: logs,
    timeline: timeline,
    memories: memories,
    notifications: notifications,
    planPreview: planPreview,
    profile: profile,
    siState: siState,
    trajectory: trajectory,
    planningDecision: planningDecision,
    sourceHealth: SISourceHealth(
      tasks: tasks.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
      goals: goals.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
      memories: memories.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
      habits: habitsHealth,
      logs: logs.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
      timeline: timeline.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
      learning: learningHealth,
      // A real work-window/calendar source is not wired yet. Keep this
      // explicit so the UI and confidence model cannot call an assumed day
      // observed availability.
      availability: SISourceStatus.unavailable,
      observedAt: observedAt,
    ),
    habits: habits,
    planningEvidence: SIPlanningEvidence(
      friction: planningSignals.friction,
      overwhelm: planningSignals.overwhelm,
      streakHealth: planningSignals.streakHealth,
      goalDrift: planningSignals.goalDrift,
      taskAvoidance: planningSignals.taskAvoidance,
      emotion: planningSignals.emotion,
      emotionalStrain: planningSignals.emotionalStrain,
      emotionalStability: planningSignals.emotionalStability,
      emotionalPatterns: planningSignals.emotionalPatterns,
      executionCompletedToday: countToday(const <String>{
        'completed_task',
        'task_completed',
        'goal_completed',
      }),
      executionSkippedToday: countToday(const <String>{'task_skipped'}),
      executionDelayedToday: countToday(const <String>{
        'task_rescheduled',
        'task_delayed',
        'task_not_completed',
      }),
    ),
  );
});

Future<List<TaskEntity>> _loadAllActiveTaskEntities(Ref ref) async {
  final List<TaskEntity> entities = await ref
      .read(domainTaskRepositoryProvider)
      .getAllTasks();
  return entities
      .where((TaskEntity item) => !item.isCompleted && !item.isCanceled)
      .toList(growable: false);
}

final siDecisionOutputProvider = FutureProvider<SIDecisionOutput>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final int timelineHealthScore = ref.watch(timelineHealthScoreProvider);
  final int timelineRiskScore = ref.watch(timelineRiskScoreProvider);
  final int timelineOverdueCount = ref.watch(timelineOverdueProvider).length;
  final int timelineUpcomingCount = ref.watch(timelineUpcomingProvider).length;
  final int timelineRiskEventsCount = ref
      .watch(timelineRiskEventsProvider)
      .length;
  final int timelineRecommendationCount = ref
      .watch(timelineRecommendationsProvider)
      .length;
  final String? rankedTaskTitle =
      aggregation.planningDecision.selectedTask?.title;

  // Decision rules live in the domain layer; this provider supplies the
  // already-derived signals and counts and maps the result to the view model.
  final SiDecisionDraft draft = ref
      .read(assembleSiDecisionOutputUseCaseProvider)
      .call(
        friction: aggregation.planningEvidence.friction,
        overwhelm: aggregation.planningEvidence.overwhelm,
        goalDrift: aggregation.planningEvidence.goalDrift,
        taskAvoidance: aggregation.planningEvidence.taskAvoidance,
        emotionalStrain: aggregation.planningEvidence.emotionalStrain,
        emotionalStability: aggregation.planningEvidence.emotionalStability,
        emotion: aggregation.planningEvidence.emotion,
        timelineHealthScore: timelineHealthScore,
        timelineRiskScore: timelineRiskScore,
        timelineOverdueCount: timelineOverdueCount,
        timelineUpcomingCount: timelineUpcomingCount,
        timelineRiskEventsCount: timelineRiskEventsCount,
        timelineRecommendationCount: timelineRecommendationCount,
        nextTaskTitle: rankedTaskTitle,
        firstTaskTitle: aggregation.tasks.isEmpty
            ? null
            : aggregation.tasks.first.title,
        taskCount: aggregation.tasks.length,
        planPreviewIsEmpty: aggregation.planPreview.isEmpty,
        hasMemories: aggregation.memories.isNotEmpty,
        memoryHint: _buildMemoryHint(aggregation.memories),
        streak: aggregation.profile.streak,
        activeHabitCount: aggregation.activeHabitCount,
      );

  return SIDecisionOutput(
    nextAction: draft.nextAction,
    plannerMessage: draft.plannerMessage,
    suggestedPlanAdjustments: draft.suggestedPlanAdjustments,
    signalPrompts: draft.signalPrompts,
    progressionFeedback: draft.progressionFeedback,
    warnings: draft.warnings,
  );
});

final smartPlannerScreenModelProvider = FutureProvider<SmartPlannerScreenModel>(
  (Ref ref) async {
    final SIStateAggregation aggregation = await ref.watch(
      siStateAggregationProvider.future,
    );
    final SIDecisionOutput decision = await ref.watch(
      siDecisionOutputProvider.future,
    );
    return SmartPlannerScreenModel(
      aggregation: aggregation,
      decision: decision,
    );
  },
);

final nexusScreenModelProvider = FutureProvider<NexusScreenModel>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput decision = await ref.watch(
    siDecisionOutputProvider.future,
  );
  return NexusScreenModel(aggregation: aggregation, decision: decision);
});

final siConsoleScreenModelProvider = FutureProvider<SIConsoleScreenModel>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput decision = await ref.watch(
    siDecisionOutputProvider.future,
  );
  final String engineSnapshot =
      'Sources available: tasks ${aggregation.tasks.length}, goals ${aggregation.goals.length}, Timeline ${aggregation.timeline.length}, memories ${aggregation.memories.length}';

  return SIConsoleScreenModel(
    aggregation: aggregation,
    decision: decision,
    engineSnapshot: engineSnapshot,
  );
});

String _buildMemoryHint(List<MemoryEntity> memories) {
  if (memories.isEmpty) {
    return 'Memory context is still light, capture one preference or reflection today.';
  }
  final MemoryEntity first = memories.first;
  final String text = first.text.trim();
  if (text.isEmpty) {
    return 'Recent memory context is available for personalization.';
  }
  final String trimmed = text.length <= 80
      ? text
      : '${text.substring(0, 79)}...';
  return 'Recall: "$trimmed"';
}
