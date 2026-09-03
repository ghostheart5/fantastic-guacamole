import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final futureConsequenceEngineProvider = Provider<FutureConsequenceEngine>(
  (Ref ref) => const FutureConsequenceEngine(),
);

final trajectoryClockProvider = Provider<DateTime Function()>(
  (Ref ref) =>
      () => DateTime.now().toUtc(),
);

const Set<PersonContextPurpose> trajectoryPersonContextPurposes =
    <PersonContextPurpose>{
      ...operationalPersonContextPurposes,
      PersonContextPurpose.outcomeLearning,
    };

final PersonContextAccessRequest trajectoryPersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.trajectory,
      purposes: trajectoryPersonContextPurposes,
    );

final trajectoryHorizonDaysProvider =
    NotifierProvider<TrajectoryHorizonController, int>(
      TrajectoryHorizonController.new,
    );

class TrajectoryHorizonController extends Notifier<int> {
  @override
  int build() => 7;

  void select(int days) {
    if (days == 7 || days == 30 || days == 90) state = days;
  }
}

enum TrajectoryCustomAdjustment { complete, delay, reduceScope }

class TrajectoryCustomScenarioDraft {
  const TrajectoryCustomScenarioDraft({
    required this.subjectId,
    required this.adjustment,
    this.delayDays = 1,
  });

  final String subjectId;
  final TrajectoryCustomAdjustment adjustment;
  final int delayDays;
}

final trajectoryCustomScenarioProvider =
    NotifierProvider<
      TrajectoryCustomScenarioController,
      TrajectoryCustomScenarioDraft?
    >(TrajectoryCustomScenarioController.new);

class TrajectoryCustomScenarioController
    extends Notifier<TrajectoryCustomScenarioDraft?> {
  @override
  TrajectoryCustomScenarioDraft? build() => null;

  void compose(TrajectoryCustomScenarioDraft draft) {
    state = draft;
  }

  void clear() => state = null;
}

String trajectoryCustomScenarioId(
  TrajectoryCustomScenarioDraft draft, {
  required int horizonDays,
}) {
  final int safeDelayDays = draft.delayDays.clamp(1, 30);
  return switch (draft.adjustment) {
    TrajectoryCustomAdjustment.complete =>
      'custom-complete-${draft.subjectId}-$horizonDays',
    TrajectoryCustomAdjustment.delay =>
      'custom-delay-${draft.subjectId}-$safeDelayDays-$horizonDays',
    TrajectoryCustomAdjustment.reduceScope =>
      'custom-reduce-${draft.subjectId}-$horizonDays',
  };
}

final trajectoryConsequenceProvider =
    Provider<AsyncValue<TrajectoryComparison>>((Ref ref) {
      final AsyncValue<SIStateAggregation> aggregationAsync = ref.watch(
        siStateAggregationProvider,
      );
      if (aggregationAsync.isLoading) {
        return const AsyncValue<TrajectoryComparison>.loading();
      }
      if (aggregationAsync.hasError) {
        return AsyncValue<TrajectoryComparison>.error(
          StateError('Current planning evidence is unavailable.'),
          aggregationAsync.stackTrace ?? StackTrace.current,
        );
      }
      final SIStateAggregation? aggregation = aggregationAsync.asData?.value;
      if (aggregation == null) {
        return AsyncValue<TrajectoryComparison>.error(
          StateError('Current planning evidence is unavailable.'),
          StackTrace.current,
        );
      }
      final ProgressionState progression = ref.watch(progressionProvider);
      final ExecutionSignals execution = ref.watch(executionSignalsProvider);
      final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
      final DateTime now = ref.watch(trajectoryClockProvider)().toUtc();
      final String accountScopeId = scope.v2Namespace ?? 'signed-out';
      final GovernedDecisionContext personContext =
          GovernedDecisionContext.resolve(
            view: ref.watch(
              personContextForSurfaceProvider(trajectoryPersonContextRequest),
            ),
            accountScopeId: accountScopeId,
            tasks: aggregation.tasks.cast<TaskEntity>(),
            now: now,
            surface: PersonContextSurface.trajectory,
          );
      final List<String> personContextAssumptions = _personContextAssumptions(
        personContext,
      );
      final int horizonDays = ref.watch(trajectoryHorizonDaysProvider);
      final TrajectoryBaseline baseline = _baseline(
        aggregation: aggregation,
        progression: progression,
        execution: execution,
        scope: scope,
        observedAt: now,
        personContext: personContext,
      );
      final List<TrajectoryIntervention> interventions =
          <TrajectoryIntervention>[
            ..._interventions(
              aggregation.noContextPlanningDecision,
              baseline,
              horizonDays: horizonDays,
              personContextAssumptions: personContextAssumptions,
            ),
          ];
      final TrajectoryCustomScenarioDraft? customDraft = ref.watch(
        trajectoryCustomScenarioProvider,
      );
      final TrajectoryIntervention? custom = customDraft == null
          ? null
          : _customIntervention(
              customDraft,
              baseline,
              horizonDays: horizonDays,
              personContextAssumptions: personContextAssumptions,
            );
      if (custom != null) {
        interventions.add(custom);
      }
      return AsyncValue<TrajectoryComparison>.data(
        ref
            .watch(futureConsequenceEngineProvider)
            .compare(
              baseline: baseline,
              interventions: interventions,
              generatedAt: now,
            ),
      );
    });

TrajectoryIntervention? _customIntervention(
  TrajectoryCustomScenarioDraft draft,
  TrajectoryBaseline baseline, {
  required int horizonDays,
  required List<String> personContextAssumptions,
}) {
  final TrajectoryTaskNode? subject = _task(baseline, draft.subjectId);
  if (subject == null) return null;
  if (baseline.boundaryTaskIds.contains(subject.id)) return null;
  if (baseline.protectedCommitmentTaskIds.contains(subject.id) &&
      draft.adjustment != TrajectoryCustomAdjustment.complete) {
    return null;
  }
  final int safeDelayDays = draft.delayDays.clamp(1, 30);
  final String scenarioId = trajectoryCustomScenarioId(
    draft,
    horizonDays: horizonDays,
  );
  return switch (draft.adjustment) {
    TrajectoryCustomAdjustment.complete => TrajectoryIntervention(
      id: scenarioId,
      type: TrajectoryInterventionType.completeTask,
      title: 'My scenario: complete ${subject.title}',
      horizon: Duration(days: horizonDays),
      description:
          'Model this commitment as completed, then compare capacity, risk, goal timing, and Progression consequences.',
      subjectId: subject.id,
      assumptions: <String>[
        'The commitment is completed without creating an unmodeled obligation.',
        'Projected Progression effects remain informational until an outcome is recorded on Timeline.',
        ...personContextAssumptions,
      ],
    ),
    TrajectoryCustomAdjustment.delay => TrajectoryIntervention(
      id: scenarioId,
      type: TrajectoryInterventionType.delayTask,
      title:
          'My scenario: delay ${subject.title} $safeDelayDays day${safeDelayDays == 1 ? '' : 's'}',
      horizon: Duration(days: horizonDays),
      description:
          'Model the declared delay and expose its deadline, capacity, goal, and risk consequences.',
      subjectId: subject.id,
      delay: Duration(days: safeDelayDays),
      assumptions: <String>[
        'The delayed commitment remains active and consumes later capacity.',
        'No replacement work is assumed unless it already exists in the baseline.',
        ...personContextAssumptions,
      ],
    ),
    TrajectoryCustomAdjustment.reduceScope => TrajectoryIntervention(
      id: scenarioId,
      type: TrajectoryInterventionType.reduceScope,
      title: 'My scenario: remove ${subject.title}',
      horizon: Duration(days: horizonDays),
      description:
          'Remove this commitment from the active capacity window and compare the resulting tradeoff.',
      subjectId: subject.id,
      displacedSubjectIds: <String>[subject.id],
      assumptions: <String>[
        'The commitment is optional or can be deferred with informed consent.',
        'The simulation does not delete or mutate the actual task.',
        ...personContextAssumptions,
      ],
    ),
  };
}

TrajectoryBaseline _baseline({
  required SIStateAggregation aggregation,
  required ProgressionState progression,
  required ExecutionSignals execution,
  required AccountStorageScope scope,
  required DateTime observedAt,
  required GovernedDecisionContext personContext,
}) {
  final DecisionRecommendation decision = aggregation.noContextPlanningDecision;
  final List<TrajectoryTaskNode> tasks = aggregation.tasks
      .map(
        (Task task) => TrajectoryTaskNode(
          id: task.id,
          title: task.title,
          priority: task.priority,
          estimatedMinutes: task.estimatedDuration.inMinutes,
          goalId: task.goalId,
          dueAt: task.dueDate?.toUtc(),
          scheduledAt: task.scheduledFor?.toUtc(),
        ),
      )
      .toList(growable: false);
  final List<TrajectoryGoalNode> goals = aggregation.goals
      .where((GoalEntity goal) => goal.isActive)
      .map(
        (GoalEntity goal) => TrajectoryGoalNode(
          id: goal.id,
          title: goal.title,
          targetDate: goal.targetDate?.toUtc(),
          linkedTaskIds: tasks
              .where((TrajectoryTaskNode task) => task.goalId == goal.id)
              .map((TrajectoryTaskNode task) => task.id)
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
  final List<TrajectoryBlockNode> blocks = decision.plan.blocks
      .where((TimeBlock block) => !block.completed)
      .map(
        (TimeBlock block) => TrajectoryBlockNode(
          id: block.id,
          taskId: block.taskId,
          start: block.start.toUtc(),
          end: block.end.toUtc(),
        ),
      )
      .toList(growable: false);
  final List<TrajectoryTimelineSignal> timeline = aggregation.timeline
      .where(
        (TimelineEventEntity event) =>
            event.relatedId != null ||
            event.dueAt != null ||
            event.isOverdue ||
            event.isRisk,
      )
      .map(
        (TimelineEventEntity event) => TrajectoryTimelineSignal(
          id: event.id,
          relatedId: event.relatedId,
          dueAt: event.dueAt?.toUtc(),
          isOverdue: event.isOverdue,
          isAtRisk: event.isRisk,
        ),
      )
      .toList(growable: false);
  final Map<String, String> revisions = <String, String>{
    'tasks': '${tasks.length}',
    'goals': '${goals.length}',
    'timeline': '${timeline.length}',
    'plan': '${blocks.length}:${decision.modelVersion}',
    'progression':
        '${progression.progress.level}:${progression.progress.xp}:${progression.progress.streak}',
    'execution':
        '${execution.completed7d}:${execution.skipped7d}:${execution.delayed7d}',
    'energy_origin': aggregation.siState.energyOrigin.name,
    'availability_origin': decision.plan.capacity.windowOrigin.name,
    'person_context_trajectory': switch (personContext.status) {
      GovernedDecisionContextStatus.unavailable => 'unavailable',
      GovernedDecisionContextStatus.knownEmpty => 'available_empty',
      GovernedDecisionContextStatus.applied => personContext.revision,
    },
  };
  final int noContextAvailable = decision.plan.capacity.availableMinutes;
  final int noContextUnscheduled = decision.plan.capacity.unscheduledMinutes;
  final int noContextFree =
      (noContextAvailable - decision.plan.capacity.occupiedMinutes).clamp(
        0,
        noContextAvailable,
      );
  final int governedFree = personContext.capacityCapMinutes == null
      ? noContextFree
      : noContextFree.clamp(0, personContext.capacityCapMinutes!);
  final int governedAvailable =
      decision.plan.capacity.occupiedMinutes + governedFree;
  final int governedUnscheduled =
      noContextUnscheduled + (noContextFree - governedFree);
  return TrajectoryBaseline(
    accountScope: scope.v2Namespace ?? 'signed-out',
    revision:
        'trajectory-v3-${_stableHash(<String>[scope.v2Namespace ?? 'signed-out', ...revisions.entries.map((MapEntry<String, String> item) => '${item.key}:${item.value}'), ...tasks.map((TrajectoryTaskNode task) => '${task.id}:${task.dueAt?.toIso8601String() ?? '-'}:${task.estimatedMinutes}')].join('|'))}',
    observedAt: observedAt,
    evidenceWindow: const Duration(days: 7),
    momentum: (aggregation.trajectory.momentum * 100).round().clamp(0, 100),
    pressure: aggregation.trajectory.pressureIndex.clamp(0, 100),
    energy: (aggregation.siState.energy * 100).round().clamp(0, 100),
    completedInWindow: execution.completed7d,
    deferredInWindow: execution.skipped7d + execution.delayed7d,
    observationCount: execution.actioned7d,
    availableMinutes: governedAvailable,
    occupiedMinutes: decision.plan.capacity.occupiedMinutes,
    unscheduledMinutes: governedUnscheduled,
    noContextAvailableMinutes: noContextAvailable,
    noContextUnscheduledMinutes: noContextUnscheduled,
    tasks: List<TrajectoryTaskNode>.unmodifiable(tasks),
    goals: List<TrajectoryGoalNode>.unmodifiable(goals),
    blocks: List<TrajectoryBlockNode>.unmodifiable(blocks),
    timelineSignals: List<TrajectoryTimelineSignal>.unmodifiable(timeline),
    progression: TrajectoryProgressionSnapshot(
      level: progression.progress.level,
      xp: progression.progress.xp,
      streak: progression.progress.streak,
    ),
    confidence: decision.confidenceProfile,
    sourceRevisions: Map<String, String>.unmodifiable(revisions),
    boundaryTaskIds: personContext.excludedTaskIds,
    protectedCommitmentTaskIds: personContext.protectedCommitmentTaskIds,
    personContextWarnings: personContext.explanations,
    personContextTrace:
        personContext.trace?.toJson() ?? const <String, Object?>{},
    energyOrigin: aggregation.siState.energyOrigin,
    availabilityOrigin: decision.plan.capacity.windowOrigin,
  );
}

List<TrajectoryIntervention> _interventions(
  DecisionRecommendation decision,
  TrajectoryBaseline baseline, {
  required int horizonDays,
  required List<String> personContextAssumptions,
}) {
  final Duration horizon = Duration(days: horizonDays);
  final TrajectoryTaskNode? selected = _task(
    baseline,
    decision.selectedTask?.id,
  );
  final TrajectoryTaskNode? recoverySubject = decision.recoveryRecommendations
      .map((item) => _task(baseline, item.subjectId))
      .whereType<TrajectoryTaskNode>()
      .firstOrNull;
  final List<TrajectoryIntervention> output = <TrajectoryIntervention>[
    TrajectoryIntervention(
      id: 'maintain-course',
      type: TrajectoryInterventionType.maintainCourse,
      title: 'Maintain current course',
      horizon: horizon,
      description: 'Preserve the current plan without a declared intervention.',
      assumptions: <String>[
        'Current completion and deferral rates remain directionally similar.',
        ...personContextAssumptions,
      ],
    ),
  ];
  if (selected != null && !baseline.boundaryTaskIds.contains(selected.id)) {
    output
      ..add(
        TrajectoryIntervention(
          id: 'apply-smart-planner',
          type: TrajectoryInterventionType.applySmartPlanner,
          title: 'Apply Smart Planner recommendation',
          horizon: horizon,
          description:
              'Protect ${selected.title} and use the feasible plan as the active schedule.',
          subjectId: selected.id,
          proposedBlocks: baseline.blocks,
          displacedSubjectIds: decision.plan.unscheduledTaskIds,
          assumptions: <String>[
            'The proposed TimeBlocks are accepted and attempted.',
            'Displaced work is explicitly reconciled instead of silently carried.',
            ...personContextAssumptions,
          ],
        ),
      )
      ..add(
        TrajectoryIntervention(
          id: 'complete-${selected.id}',
          type: TrajectoryInterventionType.completeTask,
          title: 'Complete ${selected.title}',
          horizon: horizon,
          description:
              'Model the selected Smart Planner task as completed in its feasible block.',
          subjectId: selected.id,
          assumptions: <String>[
            'The task is completed without creating an unmodeled commitment.',
            ...personContextAssumptions,
          ],
        ),
      )
      ..add(
        TrajectoryIntervention(
          id: 'delay-${selected.id}',
          type: TrajectoryInterventionType.delayTask,
          title: 'Delay ${selected.title} by one day',
          horizon: horizon,
          description:
              'Model one day of slippage and its Timeline and goal consequences.',
          subjectId: selected.id,
          delay: const Duration(days: 1),
          assumptions: <String>[
            'The delayed work remains active and consumes later capacity.',
            ...personContextAssumptions,
          ],
        ),
      );
  }
  if (recoverySubject != null &&
      !baseline.boundaryTaskIds.contains(recoverySubject.id)) {
    output.add(
      TrajectoryIntervention(
        id: 'recover-${recoverySubject.id}',
        type: TrajectoryInterventionType.recoverCommitment,
        title: 'Recover ${recoverySubject.title}',
        horizon: horizon,
        description:
            'Apply the task-specific deadline/capacity recovery recommendation.',
        subjectId: recoverySubject.id,
        displacedSubjectIds: decision.recoveryRecommendations
            .expand((item) => item.displacedSubjectIds)
            .toSet()
            .toList(growable: false),
        assumptions: <String>[
          'The first verifiable recovery checkpoint is completed.',
          ...personContextAssumptions,
        ],
      ),
    );
  }
  final List<TrajectoryTaskNode> removable =
      baseline.tasks
          .where((TrajectoryTaskNode task) => task.id != selected?.id)
          .where(
            (TrajectoryTaskNode task) =>
                !baseline.boundaryTaskIds.contains(task.id) &&
                !baseline.protectedCommitmentTaskIds.contains(task.id),
          )
          .toList(growable: false)
        ..sort((TrajectoryTaskNode a, TrajectoryTaskNode b) {
          final int priority = a.priority.compareTo(b.priority);
          return priority != 0
              ? priority
              : b.estimatedMinutes.compareTo(a.estimatedMinutes);
        });
  if (removable.isNotEmpty) {
    final TrajectoryTaskNode task = removable.first;
    output.add(
      TrajectoryIntervention(
        id: 'reduce-${task.id}',
        type: TrajectoryInterventionType.reduceScope,
        title: 'Reduce lower-priority scope',
        horizon: horizon,
        description: 'Remove ${task.title} from the active capacity window.',
        subjectId: task.id,
        assumptions: <String>[
          'The removed commitment is optional or safely deferred with consent.',
          ...personContextAssumptions,
        ],
      ),
    );
  }
  return List<TrajectoryIntervention>.unmodifiable(output);
}

TrajectoryTaskNode? _task(TrajectoryBaseline baseline, String? id) {
  if (id == null) return null;
  for (final TrajectoryTaskNode task in baseline.tasks) {
    if (task.id == id) return task;
  }
  return null;
}

String _stableHash(String value) {
  int hash = 0x811c9dc5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash.toRadixString(16);
}

List<String> _personContextAssumptions(GovernedDecisionContext context) {
  if (context.status == GovernedDecisionContextStatus.unavailable) {
    return const <String>[
      'Person context was unavailable at scenario construction, so no personal context was inferred.',
    ];
  }
  if (!context.hasAppliedBehavior) {
    return const <String>[
      'Person context was available but contained no fresh consented Trajectory operational signals.',
    ];
  }
  return <String>[
    ...context.explanations.map(
      (String explanation) =>
          'User-reported Person Context: $explanation It constrains this scenario but is not treated as identity or a guaranteed outcome.',
    ),
    'The no-context capacity and unscheduled values remain available for comparison.',
  ];
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
