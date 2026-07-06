import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siStateAggregationProvider = FutureProvider<SIStateAggregation>((Ref ref) async {
  final List<Task> tasks = await ref.watch(tasksProvider.future);
  final goals = ref.watch(goalsProvider);
  final insights = ref.watch(insightsBundleProvider);
  final logs = ref.watch(logsProvider).entries;
  final timeline = ref.watch(timelineProvider);
  final memories = ref.watch(memoriesProvider);
  final notifications = ref.watch(notificationProvider);
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final double energy = ref.watch(energyProvider);
  final AsyncValue<List<FlowmapNode>> flowmapAsync = ref.watch(flowmapProvider);
  final List<FlowmapNode> flowmapNodes = flowmapAsync.maybeWhen(
    data: (List<FlowmapNode> nodes) => nodes,
    orElse: () => const <FlowmapNode>[],
  );

  final List<String> planPreview = ref
      .read(calendarServiceProvider)
      .generateAdaptivePlan(tasks: tasks, energy: energy)
      .take(3)
      .map((block) => block.title)
      .toList(growable: false);

  final bool friction = trajectory.pressureIndex >= 60 || energy < 0.35;
  final bool overwhelm = trajectory.pressureIndex >= 75 || trajectory.behaviorDivergence >= 50;
  final String streakHealth = profile.streak >= 10
      ? 'strong'
      : profile.streak >= 3
      ? 'stable'
      : 'fragile';
  final bool goalDrift = goals.isNotEmpty && trajectory.behaviorDivergence >= 40;
  final bool taskAvoidance = logs.where((entry) => entry.source == 'task_skipped').length >= 2;
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
    signals: SISignalExtraction(
      friction: friction,
      overwhelm: overwhelm,
      streakHealth: streakHealth,
      goalDrift: goalDrift,
      taskAvoidance: taskAvoidance,
      emotionalPatterns: patterns.toList(growable: false),
    ),
  );
});

final siDecisionOutputProvider = FutureProvider<SIDecisionOutput>((Ref ref) async {
  final SIStateAggregation aggregation = await ref.watch(siStateAggregationProvider.future);
  final Task? nextTask = await ref.watch(domainSiDecisionProvider.future);

  final List<String> warnings = <String>[
    if (aggregation.signals.overwhelm) 'Overwhelm risk is elevated.',
    if (aggregation.signals.goalDrift) 'Goal drift detected in recent trajectory.',
    if (aggregation.signals.taskAvoidance) 'Task avoidance pattern detected.',
  ];

  final String nextAction =
      nextTask?.title ??
      (aggregation.tasks.isEmpty ? 'Capture one high-value task.' : aggregation.tasks.first.title);

  final List<String> planAdjustments = <String>[
    if (aggregation.signals.overwhelm) 'Reduce today to one critical task block.',
    if (aggregation.tasks.length > 5) 'Split remaining tasks into tomorrow queue.',
    if (aggregation.planPreview.isEmpty) 'Generate a 3-block adaptive plan for today.',
  ];

  final List<String> insightPrompts = <String>[
    if (aggregation.signals.friction) 'What is creating the most friction right now?',
    if (aggregation.signals.goalDrift) 'Which goal has drifted and why?',
    if (aggregation.memories.isNotEmpty) 'What memory should inform this decision?',
  ];

  final String progressionFeedback = aggregation.profile.streak >= 7
      ? 'Streak momentum is strong. Protect it with one decisive completion.'
      : aggregation.profile.streak >= 3
      ? 'Consistency is building. Keep the chain alive today.'
      : 'Rebuild momentum with one immediate win.';

  final String coachMessage = warnings.isEmpty
      ? 'Trajectory is stable. Execute the next action and keep momentum.'
      : 'Signals show pressure. Simplify scope and execute one focused action.';

  return SIDecisionOutput(
    nextAction: nextAction,
    coachMessage: coachMessage,
    suggestedPlanAdjustments: planAdjustments,
    insightPrompts: insightPrompts,
    progressionFeedback: progressionFeedback,
    warnings: warnings,
  );
});

final smartCoachScreenModelProvider = FutureProvider<SmartCoachScreenModel>((Ref ref) async {
  final SIStateAggregation aggregation = await ref.watch(siStateAggregationProvider.future);
  final SIDecisionOutput decision = await ref.watch(siDecisionOutputProvider.future);
  return SmartCoachScreenModel(aggregation: aggregation, decision: decision);
});

final nexusScreenModelProvider = FutureProvider<NexusScreenModel>((Ref ref) async {
  final SIStateAggregation aggregation = await ref.watch(siStateAggregationProvider.future);
  final SIDecisionOutput decision = await ref.watch(siDecisionOutputProvider.future);
  return NexusScreenModel(aggregation: aggregation, decision: decision);
});

final siConsoleScreenModelProvider = FutureProvider<SIConsoleScreenModel>((Ref ref) async {
  final SIStateAggregation aggregation = await ref.watch(siStateAggregationProvider.future);
  final SIDecisionOutput decision = await ref.watch(siDecisionOutputProvider.future);
  final intelligence = ref.watch(intelligenceStateProvider);
  final latestSnapshot = ref.watch(latestSiSnapshotProvider);
  final Object? state = await ref.watch(siEngineStateProvider.future);

  final List<String> chunks = <String>[intelligence.environment.appFlavor.toUpperCase()];

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
      if (latestSnapshot != null) 'MEM ${latestSnapshot.completed}/${latestSnapshot.skipped}',
    ]);
  }

  final String engineSnapshot = chunks.join(' · ').toUpperCase();

  return SIConsoleScreenModel(
    aggregation: aggregation,
    decision: decision,
    engineSnapshot: engineSnapshot,
  );
});
