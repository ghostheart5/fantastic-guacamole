import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
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
  SISourceStatus tasksStatus = SISourceStatus.ready;
  String? tasksError;
  List<Task> tasks = const <Task>[];
  try {
    tasks = await _loadAllActiveTasks(ref);
    tasksStatus = tasks.isEmpty ? SISourceStatus.empty : SISourceStatus.ready;
  } on Object catch (error) {
    tasksStatus = SISourceStatus.error;
    tasksError = error.toString();
    tasks = const <Task>[];
  }

  final goals = ref.watch(goalsProvider);
  final SISourceStatus goalsStatus = goals.isEmpty
      ? SISourceStatus.empty
      : SISourceStatus.ready;

  final InsightsBundle insights = ref.watch(insightsBundleProvider);
  final SISourceStatus insightsStatus = insights.items.isEmpty
      ? SISourceStatus.empty
      : SISourceStatus.ready;
  final logs = ref.watch(logsProvider).entries;
  final timeline = ref.watch(timelineProvider);
  final memories = ref.watch(memoriesProvider);
  final SISourceStatus memoriesStatus = memories.isEmpty
      ? SISourceStatus.empty
      : SISourceStatus.ready;
  final notifications = ref.watch(notificationProvider);
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final EmotionalState emotion = ref.watch(emotionProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final CoreValuesAlignment coreValues = ref.watch(coreValuesAlignmentProvider);
  final SoulMapAlignment soulMap = ref.watch(soulMapAlignmentProvider);
  final double energy = ref.watch(energyProvider);
  final AsyncValue<List<FlowmapNode>> flowmapAsync = ref.watch(flowmapProvider);
  final List<FlowmapNode> flowmapNodes = flowmapAsync.maybeWhen(
    data: (List<FlowmapNode> nodes) => nodes,
    orElse: () => const <FlowmapNode>[],
  );
  final SISourceStatus flowmapStatus = flowmapAsync.when(
    data: (List<FlowmapNode> nodes) => nodes.isEmpty
        ? SISourceStatus.empty
        : SISourceStatus.ready,
    loading: () => SISourceStatus.loading,
    error: (Object error, StackTrace stackTrace) => SISourceStatus.error,
  );
  final String? flowmapError = flowmapAsync.whenOrNull(
    error: (Object error, StackTrace stackTrace) => error.toString(),
  );

  final List<String> planPreview = ref
      .read(calendarServiceProvider)
      .generateAdaptivePlan(tasks: tasks, energy: energy)
      .take(3)
      .map((block) => block.title)
      .toList(growable: false);

  final bool friction = trajectory.pressureIndex >= 60 || energy < 0.35;
  final bool overwhelm =
      trajectory.pressureIndex >= 75 || trajectory.behaviorDivergence >= 50;
  final String streakHealth = profile.streak >= 10
      ? 'strong'
      : profile.streak >= 3
      ? 'stable'
      : 'fragile';
  final bool goalDrift =
      goals.isNotEmpty && trajectory.behaviorDivergence >= 40;
  final bool taskAvoidance =
      logs.where((entry) => entry.source == 'task_skipped').length >= 2;
  final bool emotionalStrain =
      emotion == EmotionalState.anxious ||
      emotion == EmotionalState.scattered ||
      emotion == EmotionalState.negative ||
      emotion == EmotionalState.fatigued;
  final bool emotionalStability =
      emotion == EmotionalState.calm ||
      emotion == EmotionalState.focused ||
      emotion == EmotionalState.positive;
  final Set<String> patterns = <String>{};
  if (insights.summary.toLowerCase().contains('overload')) {
    patterns.add('overload_pattern');
  }
  if (flowmapNodes.any((node) => node.tags.contains('insight'))) {
    patterns.add('insight_linked_flow');
  }
  if (flowmapNodes.any((node) => node.tags.contains('goal'))) {
    patterns.add('goal_pressure_pattern');
  }
  if (emotionalStrain) {
    patterns.add('emotional_strain');
  }
  if (emotionalStability) {
    patterns.add('emotional_stability');
  }

  return SIStateAggregation(
    tasks: tasks,
    goals: goals,
    insights: insights,
    flowmapNodes: flowmapNodes,
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
    sourceHealth: SISourceHealth(
      tasks: tasksStatus,
      goals: goalsStatus,
      insights: insightsStatus,
      flowmap: flowmapStatus,
      memories: memoriesStatus,
      tasksError: tasksError,
      flowmapError: flowmapError,
    ),
    signals: SISignalExtraction(
      friction: friction,
      overwhelm: overwhelm,
      streakHealth: streakHealth,
      goalDrift: goalDrift,
      taskAvoidance: taskAvoidance,
      emotion: emotion.name,
      emotionalStrain: emotionalStrain,
      emotionalStability: emotionalStability,
      emotionalPatterns: patterns.toList(growable: false),
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

  final List<String> warnings = <String>[
    if (aggregation.signals.overwhelm) 'Overwhelm risk is elevated.',
    if (aggregation.signals.goalDrift)
      'Goal drift detected in recent trajectory.',
    if (aggregation.signals.taskAvoidance) 'Task avoidance pattern detected.',
    if (aggregation.signals.emotionalStrain)
      'Emotional strain detected (${aggregation.signals.emotion}).',
    if (timelineOverdueCount > 0)
      'Timeline has $timelineOverdueCount overdue item${timelineOverdueCount == 1 ? '' : 's'}.',
    if (timelineRiskEventsCount > 0)
      'Timeline risk signals active ($timelineRiskEventsCount).',
    if (timelineHealthScore < 70)
      'Timeline health is $timelineHealthScore% with elevated risk $timelineRiskScore%.',
    if (neglectedScore < 60)
      'Core value drift detected in ${coreValueTitle(neglectedValue)} ($neglectedScore%).',
  ];

  final String nextAction =
      nextTask?.title ??
      (aggregation.tasks.isEmpty
          ? 'Capture one high-value task.'
          : aggregation.tasks.first.title);

  final List<String> planAdjustments = <String>[
    if (aggregation.signals.overwhelm)
      'Reduce today to one critical task block.',
    if (aggregation.tasks.length > 5)
      'Split remaining tasks into tomorrow queue.',
    if (aggregation.planPreview.isEmpty)
      'Generate a 3-block adaptive plan for today.',
    if (timelineOverdueCount > 0)
      'Resolve one overdue timeline item before adding new commitments.',
    if (timelineUpcomingCount >= 5)
      'Pre-plan upcoming deadlines now to prevent rollover pressure.',
    'Schedule one action that strengthens ${coreValueTitle(neglectedValue)}.',
  ];

  final List<String> insightPrompts = <String>[
    if (aggregation.signals.friction)
      'What is creating the most friction right now?',
    if (aggregation.signals.goalDrift) 'Which goal has drifted and why?',
    if (aggregation.signals.emotionalStrain)
      'What would reduce emotional load in the next hour?',
    if (aggregation.signals.emotionalStability)
      'How can you convert this stable state into one decisive action?',
    if (aggregation.memories.isNotEmpty)
      'What memory should inform this decision?',
    if (timelineOverdueCount > 0)
      'Which overdue timeline item should be recovered first?',
    if (timelineUpcomingCount > 0)
      'What is the next timeline deadline this week?',
    if (timelineRecommendationCount > 0)
      'What timeline recommendation should be applied now?',
    'How do we strengthen ${coreValueTitle(neglectedValue)} this week?',
  ];

  final String progressionFeedback = aggregation.profile.streak >= 7
      ? 'Streak momentum is strong. Protect it with one decisive completion.'
      : aggregation.profile.streak >= 3
      ? 'Consistency is building. Keep the chain alive today.'
      : 'Rebuild momentum with one immediate win.';

  final String memoryHint = _buildMemoryHint(aggregation.memories);

  final String coachMessage = warnings.isEmpty
      ? 'Trajectory is stable (timeline health $timelineHealthScore%). Strongest value is ${coreValueTitle(strongestValue)}. Execute the next action and keep momentum. $memoryHint'
      : 'Signals show pressure (timeline risk $timelineRiskScore%). Reinforce ${coreValueTitle(neglectedValue)} with one focused action now.';

  return SIDecisionOutput(
    nextAction: nextAction,
    coachMessage: coachMessage,
    suggestedPlanAdjustments: planAdjustments,
    insightPrompts: insightPrompts,
    progressionFeedback: progressionFeedback,
    warnings: warnings,
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
