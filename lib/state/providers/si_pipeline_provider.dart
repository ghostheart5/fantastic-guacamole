import 'package:fantastic_guacamole/data/repositories/habit_repository.dart'
    show HabitRecord;
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/usecases/assemble_si_decision_output.dart';
import 'package:fantastic_guacamole/domain/usecases/extract_si_signals.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siStateAggregationProvider = FutureProvider<SIStateAggregation>((
  Ref ref,
) async {
  final List<Task> tasks = await _loadAllActiveTasks(ref);
  final goals = ref.watch(goalsProvider);
  final insights = ref.watch(insightsBundleProvider);
  final logs = ref.watch(logsProvider).entries;
  final timeline = ref.watch(timelineProvider);
  final memories = ref.watch(memoriesProvider);
  final notifications = ref.watch(notificationProvider);
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final EmotionalState emotion = ref.watch(emotionProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final CoreValuesAlignment coreValues = ref.watch(coreValuesAlignmentProvider);
  final SoulMapAlignment soulMap = ref.watch(soulMapAlignmentProvider);
  final double energy = ref.watch(energyProvider);
  // Habits feed Smart Planner and SI. Read non-blocking: if habit storage has
  // not resolved (or failed), aggregation continues with none rather than
  // stalling the whole SI pipeline on it.
  final List<HabitRecord> habits = ref
      .watch(habitsProvider)
      .maybeWhen(
        data: (List<HabitRecord> value) => value,
        orElse: () => const <HabitRecord>[],
      );

  final List<String> planPreview = ref
      .read(generateAdaptivePlanUseCaseProvider)
      .call(tasks: tasks, energy: energy)
      .take(3)
      .map((block) => block.title)
      .toList(growable: false);

  // Signal thresholds live in the domain layer so this provider orchestrates
  // rather than owning core SI logic.
  final SiSignals signals = ref
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
        insightsSummary: insights.summary,
      );

  return SIStateAggregation(
    tasks: tasks,
    goals: goals,
    insights: insights,
    logs: logs,
    timeline: timeline,
    memories: memories,
    notifications: notifications,
    planPreview: planPreview,
    profile: profile,
    siState: siState,
    trajectory: trajectory,
    coreValues: coreValues,
    soulMap: soulMap,
    habits: habits,
    signals: SISignalExtraction(
      friction: signals.friction,
      overwhelm: signals.overwhelm,
      streakHealth: signals.streakHealth,
      goalDrift: signals.goalDrift,
      taskAvoidance: signals.taskAvoidance,
      emotion: signals.emotion,
      emotionalStrain: signals.emotionalStrain,
      emotionalStability: signals.emotionalStability,
      emotionalPatterns: signals.emotionalPatterns,
    ),
  );
});

Future<List<Task>> _loadAllActiveTasks(Ref ref) async {
  final List<TaskEntity> entities = await ref
      .read(domainTaskRepositoryProvider)
      .getAllTasks();
  return entities
      .where((TaskEntity item) => !item.isCompleted && !item.isCanceled)
      .map(
        (TaskEntity item) => Task(
          id: item.id,
          title: item.title,
          priority: item.priority,
          difficulty: item.difficulty,
          energyRequired: item.energyRequired,
          scheduledFor: item.scheduledFor,
          goalId: item.goalId,
          subtasks: item.subtasks,
          recurrenceRule: item.recurrenceRule,
        ),
      )
      .toList(growable: false);
}

final siDecisionOutputProvider = FutureProvider<SIDecisionOutput>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final Task? nextTask = await ref.watch(domainSiDecisionProvider.future);
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
  final CoreValuesAlignment coreValues = ref.watch(coreValuesAlignmentProvider);
  final CoreValueType neglectedValue = coreValues.mostNeglected;
  final CoreValueType strongestValue = coreValues.strongest;
  final int neglectedScore = coreValues.scores[neglectedValue]?.score ?? 0;

  // Decision rules live in the domain layer; this provider supplies the
  // already-derived signals and counts and maps the result to the view model.
  final SiDecisionDraft draft = ref
      .read(assembleSiDecisionOutputUseCaseProvider)
      .call(
        friction: aggregation.signals.friction,
        overwhelm: aggregation.signals.overwhelm,
        goalDrift: aggregation.signals.goalDrift,
        taskAvoidance: aggregation.signals.taskAvoidance,
        emotionalStrain: aggregation.signals.emotionalStrain,
        emotionalStability: aggregation.signals.emotionalStability,
        emotion: aggregation.signals.emotion,
        timelineHealthScore: timelineHealthScore,
        timelineRiskScore: timelineRiskScore,
        timelineOverdueCount: timelineOverdueCount,
        timelineUpcomingCount: timelineUpcomingCount,
        timelineRiskEventsCount: timelineRiskEventsCount,
        timelineRecommendationCount: timelineRecommendationCount,
        neglectedValueLabel: coreValueTitle(neglectedValue),
        strongestValueLabel: coreValueTitle(strongestValue),
        neglectedValueScore: neglectedScore,
        nextTaskTitle: nextTask?.title,
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
    coachMessage: draft.coachMessage,
    suggestedPlanAdjustments: draft.suggestedPlanAdjustments,
    insightPrompts: draft.insightPrompts,
    progressionFeedback: draft.progressionFeedback,
    warnings: draft.warnings,
  );
});

final smartCoachScreenModelProvider = FutureProvider<SmartCoachScreenModel>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput decision = await ref.watch(
    siDecisionOutputProvider.future,
  );
  return SmartCoachScreenModel(aggregation: aggregation, decision: decision);
});

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
  final CoreValuesAlignment coreValues = aggregation.coreValues;
  final SoulMapAlignment soulMap = aggregation.soulMap;
  final intelligence = ref.watch(intelligenceStateProvider);
  final latestSnapshot = ref.watch(latestSiSnapshotProvider);
  final Object? state = await ref.watch(siEngineStateProvider.future);

  final List<String> chunks = <String>[
    intelligence.environment.appFlavor.toUpperCase(),
  ];

  if (state == null) {
    if (latestSnapshot != null) {
      chunks.add('MEM ${latestSnapshot.completed}/${latestSnapshot.skipped}');
    }
  }

  if (state is Map<String, dynamic>) {
    final String personality = state['personality']?.toString() ?? '';
    final String emotion = state['emotion']?.toString() ?? '';
    final String confidence = state['confidence'] is num
        ? '${((state['confidence'] as num) * 100).round()}%'
        : '';
    chunks.addAll(<String>[
      if (personality.isNotEmpty) personality,
      if (emotion.isNotEmpty) emotion,
      if (confidence.isNotEmpty) confidence,
      if (latestSnapshot != null)
        'MEM ${latestSnapshot.completed}/${latestSnapshot.skipped}',
    ]);
  }

  final String engineSnapshot = chunks.join(' · ').toUpperCase();
  final String valuesSnapshot =
      'VALUES ${coreValues.overall}% · LOW ${coreValueTitle(coreValues.mostNeglected).toUpperCase()} ${coreValues.scores[coreValues.mostNeglected]?.score ?? 0}%';
  final String soulMapSnapshot =
      'SOULMAP ${soulMap.overall}% · LOW ${soulMapDimensionTitle(soulMap.weakest).toUpperCase()} ${soulMap.scores[soulMap.weakest]?.score ?? 0}%';

  return SIConsoleScreenModel(
    aggregation: aggregation,
    decision: decision,
    engineSnapshot: '$engineSnapshot · $valuesSnapshot · $soulMapSnapshot',
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
