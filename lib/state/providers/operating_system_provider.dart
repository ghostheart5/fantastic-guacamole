import 'dart:async';

import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/operating_continuity_repository.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/operating_system/i_operating_continuity_repository.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final operatingContinuityRepositoryProvider =
    Provider<IOperatingContinuityRepository>((Ref ref) {
      return OperatingContinuityRepository(ref.watch(sharedPrefsStoreProvider));
    });

const Set<PersonContextPurpose> nexusPersonContextPurposes =
    sharedDecisionPersonContextPurposes;

final PersonContextAccessRequest nexusPersonContextRequest =
    sharedDecisionPersonContextRequest;

const Set<PersonContextSurface> sharedDecisionContextSurfaces =
    <PersonContextSurface>{
      PersonContextSurface.smartPlanner,
      PersonContextSurface.siConsole,
      PersonContextSurface.nexus,
      PersonContextSurface.trajectory,
    };

enum OperatingDecisionSurface {
  smartPlanner,
  nexus,
  timeline,
  trajectory,
  siConsole,
  notifications,
}

class SurfaceDecisionReceipt {
  const SurfaceDecisionReceipt({required this.surface, required this.receipt});

  final OperatingDecisionSurface surface;
  final OperatingDecisionReceipt receipt;
}

final operatingDecisionForSurfaceProvider =
    FutureProvider.family<SurfaceDecisionReceipt, OperatingDecisionSurface>((
      Ref ref,
      OperatingDecisionSurface surface,
    ) async {
      final OperatingDecisionReceipt receipt = await ref.watch(
        operatingDecisionReceiptProvider.future,
      );
      return SurfaceDecisionReceipt(surface: surface, receipt: receipt);
    });

final operatingSnapshotProvider = FutureProvider<OperatingSnapshot>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput supportingOutput = await ref.watch(
    siDecisionOutputProvider.future,
  );
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final String accountScope = scope.v2Namespace ?? 'ephemeral';
  final String? subjectId = aggregation.planningDecision.selectedTask?.id;
  final String recommendedAction = _canonicalRecommendedAction(aggregation);
  final Map<String, String> revisions = operatingSourceRevisions(aggregation);
  return OperatingSnapshot(
    accountScope: accountScope,
    observedAt: DateTime.now().toUtc(),
    sourceRevisions: revisions,
    activeGoalCount: aggregation.goals.length,
    actionableCount: aggregation.tasks.length,
    overdueCount: aggregation.timeline.where((item) => item.isOverdue).length,
    completedToday: aggregation.planningEvidence.executionCompletedToday,
    energy: aggregation.siState.energy,
    fatigue: aggregation.siState.fatigue,
    energyOrigin: aggregation.siState.energyOrigin,
    fatigueOrigin: aggregation.siState.fatigueOrigin,
    momentum: (aggregation.trajectory.momentum * 100).round().clamp(0, 100),
    pressure: aggregation.trajectory.pressureIndex.clamp(0, 100),
    topActionId: subjectId,
    topActionLabel: recommendedAction,
    activeRisks: supportingOutput.warnings,
    evidenceCoverage: aggregation.sourceHealth.availableFraction,
  );
});

final operatingDecisionPlanProvider = FutureProvider<OperatingDecisionPlan>((
  Ref ref,
) async {
  final OperatingSnapshot snapshot = await ref.watch(
    operatingSnapshotProvider.future,
  );
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  return OperatingDecisionPlan(
    snapshotId: snapshot.snapshotId,
    subjectId: snapshot.topActionId,
    recommendedAction: _canonicalRecommendedAction(aggregation),
    sourceRevisions: snapshot.sourceRevisions,
    modelVersion: aggregation.planningDecision.modelVersion,
  );
});

final operatingDecisionReceiptProvider = FutureProvider<OperatingDecisionReceipt>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput supportingOutput = await ref.watch(
    siDecisionOutputProvider.future,
  );
  final OperatingSnapshot snapshot = await ref.watch(
    operatingSnapshotProvider.future,
  );
  final OperatingDecisionPlan plan = await ref.watch(
    operatingDecisionPlanProvider.future,
  );
  final DateTime now = DateTime.now().toUtc();
  final GovernedDecisionContext? personContext =
      aggregation.planningDecision.personContext;
  final Map<String, String> receiptRevisions = <String, String>{
    ...snapshot.sourceRevisions,
    'person_context_shared': personContext?.revision ?? 'unavailable',
    'person_context_nexus': personContext?.revision ?? 'unavailable',
  };
  final String? subjectId = plan.subjectId;
  final String recommendedAction = plan.recommendedAction;
  final bool isCaptureAction = subjectId == null;
  final List<OperatingEvidence> evidence = <OperatingEvidence>[
    OperatingEvidence(
      code: 'ranked_action',
      description: subjectId == null
          ? 'No active task was available, so Creator is the next planning step.'
          : 'The action was selected from current task, schedule, energy, and friction signals.',
      kind: OperatingEvidenceKind.derived,
      recordedAt: now,
      source: 'si_pipeline',
      subjectId: subjectId,
      freshUntil: now.add(const Duration(minutes: 20)),
    ),
    OperatingEvidence(
      code: 'energy_state',
      description:
          aggregation.siState.hasObservedEnergy &&
              aggregation.siState.hasObservedFatigue
          ? 'User-reported energy ${(aggregation.siState.energy * 100).round()}% and fatigue ${(aggregation.siState.fatigue * 100).round()}% shaped execution intensity.'
          : 'Current energy or fatigue was not reported. Neutral internal fallbacks are not treated as personal evidence.',
      kind:
          aggregation.siState.hasObservedEnergy &&
              aggregation.siState.hasObservedFatigue
          ? OperatingEvidenceKind.observed
          : OperatingEvidenceKind.unavailable,
      recordedAt: now,
      source: 'current_state',
      freshUntil: now.add(const Duration(minutes: 20)),
    ),
    OperatingEvidence(
      code: 'evidence_coverage',
      description:
          '${(snapshot.evidenceCoverage * 100).round()}% of core evidence sources are currently ready.',
      kind: OperatingEvidenceKind.derived,
      recordedAt: now,
      source: 'source_health',
    ),
  ];
  evidence.addAll(_personContextEvidence(personContext, now));
  final TaskScoreBreakdown? score = _scoreFor(
    aggregation.planningDecision.rankedCandidates,
    subjectId,
  );
  if (score != null) {
    evidence.addAll(<OperatingEvidence>[
      OperatingEvidence(
        code: 'priority_score',
        description:
            'Priority contributed ${score.priority.toStringAsFixed(1)} ranking points.',
        kind: OperatingEvidenceKind.derived,
        recordedAt: now,
        source: 'predictive_planning_v2',
        subjectId: subjectId,
        weight: score.priority,
      ),
      OperatingEvidence(
        code: 'deadline_pressure',
        description: score.deadlinePressure.explanation,
        kind: score.deadlinePressure.origin == PredictiveEvidenceOrigin.observed
            ? OperatingEvidenceKind.observed
            : OperatingEvidenceKind.unavailable,
        recordedAt: now,
        source: 'predictive_planning_v2',
        subjectId: subjectId,
        weight: score.deadlinePressure.score,
      ),
    ]);
  }
  final capacity = aggregation.planningDecision.plan.capacity;
  evidence.add(
    OperatingEvidence(
      code: 'capacity_assessment',
      description: capacity.windowOrigin == PredictiveEvidenceOrigin.observed
          ? '${capacity.requiredMinutes} required minutes against ${capacity.freeMinutes} available minutes; ${capacity.unscheduledMinutes} minutes unscheduled.'
          : 'Estimated capacity uses an assumed planning window: ${capacity.requiredMinutes} required minutes, ${capacity.freeMinutes} modeled minutes available, and ${capacity.unscheduledMinutes} minutes unscheduled. This is not current calendar availability.',
      kind: capacity.windowOrigin == PredictiveEvidenceOrigin.observed
          ? OperatingEvidenceKind.observed
          : OperatingEvidenceKind.estimated,
      recordedAt: now,
      source: 'predictive_planning_v2',
    ),
  );
  final OperatingConfidence confidence =
      switch (aggregation.planningDecision.confidenceProfile.band) {
        PredictiveConfidenceBand.high => OperatingConfidence.high,
        PredictiveConfidenceBand.moderate => OperatingConfidence.moderate,
        PredictiveConfidenceBand.low => OperatingConfidence.low,
        PredictiveConfidenceBand.insufficientEvidence =>
          OperatingConfidence.insufficientEvidence,
      };
  final String rationale = subjectId == null
      ? 'An actionable commitment is required before ChronoSpark can rank execution.'
      : aggregation.planningDecision.rationale;
  final String? personContextExplanation =
      personContext?.hasAppliedBehavior ?? false
      ? personContext!.explanations.first
      : null;
  final String whyItMatters =
      personContextExplanation ??
      (capacity.isOverloaded
          ? 'It protects the highest-ranked commitment while the current plan exceeds modeled capacity.'
          : snapshot.overdueCount > 0
          ? 'It reduces current schedule risk and prevents overdue pressure from compounding.'
          : 'It converts the strongest available signal into measurable forward movement.');
  final String consequence = capacity.isOverloaded
      ? 'Without reducing or moving work, ${capacity.unscheduledMinutes} minutes remain outside available capacity.'
      : snapshot.overdueCount > 0
      ? 'Waiting can increase rollover pressure and reduce schedule flexibility.'
      : 'Waiting leaves the current priority unresolved and makes your next step less clear.';
  final OperatingActionType intentType;
  final String intentLabel;
  final String intentDestination;
  if (isCaptureAction) {
    intentType = OperatingActionType.openCreator;
    intentLabel = 'Open Creator';
    intentDestination = RoutePaths.creator;
  } else if (capacity.isOverloaded) {
    intentType = OperatingActionType.openSmartPlanner;
    intentLabel = 'Reconcile in Smart Planner';
    intentDestination = RoutePaths.smartPlanner;
  } else if (snapshot.evidenceCoverage < .5) {
    intentType = OperatingActionType.openSiConsole;
    intentLabel = 'Review evidence in SI Console';
    intentDestination = RoutePaths.siConsole;
  } else if (snapshot.pressure >= 80 && snapshot.overdueCount == 0) {
    intentType = OperatingActionType.openTrajectoryEngine;
    intentLabel = 'Review risk in Trajectory Engine';
    intentDestination = RoutePaths.trajectoryEngine;
  } else if (snapshot.momentum < 30 && snapshot.completedToday > 0) {
    intentType = OperatingActionType.openProgression;
    intentLabel = 'Review recovery in Progression';
    intentDestination = RoutePaths.progression;
  } else {
    intentType = OperatingActionType.openTimeline;
    intentLabel = 'Review on Timeline';
    intentDestination = RoutePaths.timeline;
  }
  final OperatingActionIntent intent = OperatingActionIntent(
    id: stableId(<String, dynamic>{
      'subject': subjectId,
      'action': recommendedAction,
      'snapshot': snapshot.snapshotId,
    }),
    type: intentType,
    label: intentLabel,
    destination: intentDestination,
    targetEntityId: subjectId,
  );
  final OperatingDecisionReceipt receipt = OperatingDecisionReceipt(
    snapshotId: plan.snapshotId,
    planId: plan.planId,
    subjectId: subjectId,
    recommendedAction: recommendedAction,
    rationale: rationale,
    whyItMatters: whyItMatters,
    consequenceOfDelay: consequence,
    generatedAt: now,
    expiresAt: now.add(const Duration(minutes: 20)),
    confidence: confidence,
    recommendationConfidence:
        aggregation.planningDecision.confidenceProfile.recommendationConfidence,
    evidence: evidence,
    actionIntent: intent,
    sourceRevisions: Map<String, String>.unmodifiable(receiptRevisions),
    modelVersion: plan.modelVersion,
    personContextAppliedSignalIds:
        personContext?.appliedSignalIds.toList(growable: false) ??
        const <String>[],
    personContextExplanations: personContext?.explanations ?? const <String>[],
    personContextTrace: personContext?.trace?.toJson(),
    assumptions: <String>[
      ...capacity.assumptions,
      'Current local records represent the user intent available to ChronoSpark.',
      'Deterministic ranking is decision support, not a guaranteed outcome.',
      ..._personContextAssumptions(personContext),
    ],
    warnings: supportingOutput.warnings,
  );
  receipt.validate();
  final Duration untilExpiry = receipt.expiresAt.difference(
    DateTime.now().toUtc(),
  );
  final Timer expiryTimer = Timer(
    untilExpiry.isNegative ? Duration.zero : untilExpiry,
    ref.invalidateSelf,
  );
  ref.onDispose(expiryTimer.cancel);
  return receipt;
});

final decisionIntelligenceProvider = FutureProvider<DecisionIntelligence>((
  Ref ref,
) async {
  final OperatingSnapshot snapshot = await ref.watch(
    operatingSnapshotProvider.future,
  );
  final OperatingDecisionReceipt decision = await ref.watch(
    operatingDecisionReceiptProvider.future,
  );
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable || scope.v2Namespace == null) {
    return DecisionIntelligence(
      snapshot: snapshot,
      delta: const OperatingDeltaEngine().compare(
        previous: null,
        current: snapshot,
      ),
      decision: decision,
      acknowledgedSnapshotId: null,
    );
  }
  final String accountScope = scope.v2Namespace!;
  final IOperatingContinuityRepository repository = ref.watch(
    operatingContinuityRepositoryProvider,
  );
  final List<OperatingSnapshot> history = await repository.loadHistory(
    accountScope,
  );
  final String? acknowledgedId = await repository.loadAcknowledgedSnapshotId(
    accountScope,
  );
  OperatingSnapshot? previous;
  if (acknowledgedId != null) {
    for (final OperatingSnapshot item in history.reversed) {
      if (item.snapshotId == acknowledgedId) {
        previous = item;
        break;
      }
    }
  }
  previous ??= history.isEmpty ? null : history.last;
  await repository.saveSnapshot(accountScope, snapshot);
  return DecisionIntelligence(
    snapshot: snapshot,
    delta: const OperatingDeltaEngine().compare(
      previous: previous,
      current: snapshot,
    ),
    decision: decision,
    acknowledgedSnapshotId: acknowledgedId,
  );
});

final operatingContinuityActionsProvider = Provider<OperatingContinuityActions>(
  OperatingContinuityActions.new,
);

class OperatingContinuityActions {
  OperatingContinuityActions(this._ref);

  final Ref _ref;

  Future<void> acknowledgeCurrentDecision() async {
    final AccountStorageScope scope = _ref.read(accountStorageScopeProvider);
    final String? accountScope = scope.v2Namespace;
    if (!scope.isWritable || accountScope == null) return;
    final DecisionIntelligence intelligence = await _ref.read(
      decisionIntelligenceProvider.future,
    );
    await _ref
        .read(operatingContinuityRepositoryProvider)
        .acknowledge(accountScope, intelligence.snapshot.snapshotId);
    _ref.invalidate(decisionIntelligenceProvider);
  }
}

/// Semantic hashes ensure continuity changes when decision-relevant content
/// changes, even when list counts remain identical.
Map<String, String> operatingSourceRevisions(SIStateAggregation aggregation) {
  final List<Map<String, dynamic>> tasks =
      aggregation.tasks.map((task) => task.toJson()).toList(growable: false)
        ..sort(
          (first, second) => '${first['id']}'.compareTo('${second['id']}'),
        );
  final List<Map<String, dynamic>> goals =
      aggregation.goals.map((goal) => goal.toJson()).toList(growable: false)
        ..sort(
          (first, second) => '${first['id']}'.compareTo('${second['id']}'),
        );
  final List<Map<String, dynamic>> timeline =
      aggregation.timeline
          .map((event) => event.toJson())
          .toList(growable: false)
        ..sort(
          (first, second) => '${first['id']}'.compareTo('${second['id']}'),
        );
  final List<Map<String, dynamic>> blocks =
      aggregation.planningDecision.plan.blocks
          .map(
            (block) => <String, dynamic>{
              'id': block.id,
              'taskId': block.taskId,
              'title': block.title,
              'start': block.start.toUtc().toIso8601String(),
              'end': block.end.toUtc().toIso8601String(),
              'completed': block.completed,
            },
          )
          .toList(growable: false)
        ..sort(
          (first, second) => '${first['id']}'.compareTo('${second['id']}'),
        );
  return <String, String>{
    'tasks': stableId(<String, dynamic>{'items': tasks}),
    'goals': stableId(<String, dynamic>{'items': goals}),
    'timeline': stableId(<String, dynamic>{'items': timeline}),
    'execution': stableId(<String, dynamic>{
      'completedToday': aggregation.planningEvidence.executionCompletedToday,
      'skippedToday': aggregation.planningEvidence.executionSkippedToday,
      'delayedToday': aggregation.planningEvidence.executionDelayedToday,
    }),
    'plan': stableId(<String, dynamic>{
      'modelVersion': aggregation.planningDecision.modelVersion,
      'selectedTaskId': aggregation.planningDecision.selectedTask?.id,
      'blocks': blocks,
      'capacity': <String, dynamic>{
        'required': aggregation.planningDecision.plan.capacity.requiredMinutes,
        'free': aggregation.planningDecision.plan.capacity.freeMinutes,
        'unscheduled':
            aggregation.planningDecision.plan.capacity.unscheduledMinutes,
        'windowOrigin':
            aggregation.planningDecision.plan.capacity.windowOrigin.name,
      },
    }),
    'trajectory': stableId(<String, dynamic>{
      'momentum': aggregation.trajectory.momentum,
      'pressure': aggregation.trajectory.pressureIndex,
      'divergence': aggregation.trajectory.behaviorDivergence,
      'pending': aggregation.trajectory.pendingTasks,
      'completed': aggregation.trajectory.completedTasks,
    }),
    'progression': stableId(<String, dynamic>{
      'level': aggregation.profile.level,
      'xp': aggregation.profile.xp,
      'streak': aggregation.profile.streak,
    }),
    'state': stableId(<String, dynamic>{
      'energy': aggregation.siState.energy,
      'fatigue': aggregation.siState.fatigue,
      'energyOrigin': aggregation.siState.energyOrigin.name,
      'fatigueOrigin': aggregation.siState.fatigueOrigin.name,
      'sourceHealth': <String, String>{
        'tasks': aggregation.sourceHealth.tasks.name,
        'goals': aggregation.sourceHealth.goals.name,
        'memories': aggregation.sourceHealth.memories.name,
        'habits': aggregation.sourceHealth.habits.name,
        'logs': aggregation.sourceHealth.logs.name,
        'timeline': aggregation.sourceHealth.timeline.name,
        'learning': aggregation.sourceHealth.learning.name,
        'availability': aggregation.sourceHealth.availability.name,
      },
    }),
  };
}

String _canonicalRecommendedAction(SIStateAggregation aggregation) {
  final planningDecision = aggregation.planningDecision;
  if (planningDecision.shouldTakeBreak) {
    return 'Take a short recovery break before choosing more work.';
  }
  final selected = planningDecision.selectedTask;
  if (selected != null) {
    return 'Work on: ${selected.title}';
  }
  if (aggregation.tasks.isEmpty) {
    return 'Capture one actionable task in Creator.';
  }
  return 'Reconcile unscheduled work in Smart Planner.';
}

TaskScoreBreakdown? _scoreFor(List<RankedTask> ranked, String? subjectId) {
  if (subjectId == null) return null;
  for (final RankedTask item in ranked) {
    if (item.task.id == subjectId) return item.breakdown;
  }
  return null;
}

List<OperatingEvidence> _personContextEvidence(
  GovernedDecisionContext? context,
  DateTime recordedAt,
) {
  if (context == null ||
      context.status == GovernedDecisionContextStatus.unavailable) {
    return <OperatingEvidence>[
      OperatingEvidence(
        code: 'person_context_unavailable',
        description:
            'Governed person context was unavailable to the shared decision authority. No personal context was assumed.',
        kind: OperatingEvidenceKind.unavailable,
        recordedAt: recordedAt,
        source: 'person_context',
      ),
    ];
  }
  if (context.status == GovernedDecisionContextStatus.knownEmpty) {
    return <OperatingEvidence>[
      OperatingEvidence(
        code: 'person_context_available_empty',
        description:
            'No fresh consented context passed the governed Nexus behavior policy.',
        kind: OperatingEvidenceKind.unavailable,
        recordedAt: recordedAt,
        source: 'person_context',
      ),
    ];
  }
  return context.explanations
      .map(
        (String explanation) => OperatingEvidence(
          code:
              'person_context_${stableId(<String, dynamic>{'explanation': explanation})}',
          description: explanation,
          kind: OperatingEvidenceKind.derived,
          recordedAt: recordedAt,
          source: 'person_context_policy',
        ),
      )
      .toList(growable: false);
}

List<String> _personContextAssumptions(GovernedDecisionContext? context) {
  if (context == null ||
      context.status == GovernedDecisionContextStatus.unavailable) {
    return const <String>[
      'Person context was unavailable at decision generation, so no personal context was inferred.',
    ];
  }
  if (context.status == GovernedDecisionContextStatus.knownEmpty) {
    return const <String>[
      'Person context was available but no signal passed the governed Nexus behavior policy.',
    ];
  }
  return const <String>[
    'Only consented, fresh, relevant Person Context changed its policy-permitted field; it was not interpreted as identity, diagnosis, intent, relationship quality, or a guaranteed outcome.',
  ];
}
