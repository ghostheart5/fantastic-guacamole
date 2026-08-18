import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/operating_continuity_repository.dart';
import 'package:fantastic_guacamole/domain/operating_system/i_operating_continuity_repository.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final operatingContinuityRepositoryProvider =
    Provider<IOperatingContinuityRepository>((Ref ref) {
      return OperatingContinuityRepository(ref.watch(sharedPrefsStoreProvider));
    });

final operatingSnapshotProvider = FutureProvider<OperatingSnapshot>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput decision = await ref.watch(
    siDecisionOutputProvider.future,
  );
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final String accountScope = scope.v2Namespace ?? 'ephemeral';
  final String? subjectId = aggregation.planningDecision.selectedTask?.id;
  final int readySources = <SISourceStatus>[
    aggregation.sourceHealth.tasks,
    aggregation.sourceHealth.goals,
    aggregation.sourceHealth.memories,
  ].where((SISourceStatus item) => item == SISourceStatus.ready).length;
  final Map<String, String> revisions = <String, String>{
    'tasks': '${aggregation.tasks.length}',
    'goals': '${aggregation.goals.length}',
    'timeline': '${aggregation.timeline.length}',
    'completedToday': '${aggregation.signals.executionCompletedToday}',
    'skippedToday': '${aggregation.signals.executionSkippedToday}',
    'delayedToday': '${aggregation.signals.executionDelayedToday}',
    'plan':
        '${aggregation.planPreview.length}:${aggregation.planningDecision.modelVersion}',
    'trajectory':
        '${aggregation.trajectory.momentum}:${aggregation.trajectory.pressureIndex}',
    'progression': '${aggregation.profile.level}:${aggregation.profile.streak}',
  };
  return OperatingSnapshot(
    accountScope: accountScope,
    observedAt: DateTime.now().toUtc(),
    sourceRevisions: revisions,
    activeGoalCount: aggregation.goals.length,
    actionableCount: aggregation.tasks.length,
    overdueCount: aggregation.timeline.where((item) => item.isOverdue).length,
    completedToday: aggregation.signals.executionCompletedToday,
    energy: aggregation.siState.energy,
    fatigue: aggregation.siState.fatigue,
    momentum: (aggregation.trajectory.momentum * 100).round().clamp(0, 100),
    pressure: aggregation.trajectory.pressureIndex.clamp(0, 100),
    topActionId: subjectId,
    topActionLabel: decision.nextAction,
    activeRisks: decision.warnings,
    evidenceCoverage: readySources / 3,
  );
});

final operatingDecisionReceiptProvider = FutureProvider<OperatingDecisionReceipt>((
  Ref ref,
) async {
  final SIStateAggregation aggregation = await ref.watch(
    siStateAggregationProvider.future,
  );
  final SIDecisionOutput decision = await ref.watch(
    siDecisionOutputProvider.future,
  );
  final OperatingSnapshot snapshot = await ref.watch(
    operatingSnapshotProvider.future,
  );
  final DateTime now = DateTime.now().toUtc();
  final String? subjectId = snapshot.topActionId;
  final bool isCaptureAction = subjectId == null;
  final List<OperatingEvidence> evidence = <OperatingEvidence>[
    OperatingEvidence(
      code: 'ranked_action',
      description: subjectId == null
          ? 'No active task was available, so Creator is the next operating step.'
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
          'Energy ${(aggregation.siState.energy * 100).round()}% and fatigue ${(aggregation.siState.fatigue * 100).round()}% shaped execution intensity.',
      kind: OperatingEvidenceKind.observed,
      recordedAt: now,
      source: 'current_state',
      freshUntil: now.add(const Duration(minutes: 20)),
    ),
    OperatingEvidence(
      code: 'evidence_coverage',
      description:
          '${(snapshot.evidenceCoverage * 100).round()}% of core operating sources are currently ready.',
      kind: OperatingEvidenceKind.derived,
      recordedAt: now,
      source: 'source_health',
    ),
  ];
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
      description:
          '${capacity.requiredMinutes} required minutes against ${capacity.freeMinutes} currently free minutes; ${capacity.unscheduledMinutes} minutes unscheduled.',
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
  final String whyItMatters = capacity.isOverloaded
      ? 'It protects the highest-ranked commitment while the current plan exceeds modeled capacity.'
      : snapshot.overdueCount > 0
      ? 'It reduces current schedule risk and prevents overdue pressure from compounding.'
      : 'It converts the strongest available signal into measurable forward movement.';
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
      'action': decision.nextAction,
      'snapshot': snapshot.snapshotId,
    }),
    type: intentType,
    label: intentLabel,
    destination: intentDestination,
    targetEntityId: subjectId,
  );
  final OperatingDecisionReceipt receipt = OperatingDecisionReceipt(
    subjectId: subjectId,
    recommendedAction: decision.nextAction,
    rationale: rationale,
    whyItMatters: whyItMatters,
    consequenceOfDelay: consequence,
    generatedAt: now,
    expiresAt: now.add(const Duration(minutes: 20)),
    confidence: confidence,
    evidence: evidence,
    actionIntent: intent,
    sourceRevisions: snapshot.sourceRevisions,
    modelVersion: aggregation.planningDecision.modelVersion,
    assumptions: <String>[
      ...capacity.assumptions,
      'Current local records represent the user intent available to ChronoSpark.',
      'Deterministic ranking is decision support, not a guaranteed outcome.',
    ],
    warnings: decision.warnings,
  );
  receipt.validate();
  return receipt;
});

final operatingBriefingProvider = FutureProvider<OperatingBriefing>((
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
    return OperatingBriefing(
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
  return OperatingBriefing(
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

  Future<void> acknowledgeCurrentBriefing() async {
    final AccountStorageScope scope = _ref.read(accountStorageScopeProvider);
    final String? accountScope = scope.v2Namespace;
    if (!scope.isWritable || accountScope == null) return;
    final OperatingBriefing briefing = await _ref.read(
      operatingBriefingProvider.future,
    );
    await _ref
        .read(operatingContinuityRepositoryProvider)
        .acknowledge(accountScope, briefing.snapshot.snapshotId);
    _ref.invalidate(operatingBriefingProvider);
  }
}

TaskScoreBreakdown? _scoreFor(List<RankedTask> ranked, String? subjectId) {
  if (subjectId == null) return null;
  for (final RankedTask item in ranked) {
    if (item.task.id == subjectId) return item.breakdown;
  }
  return null;
}
