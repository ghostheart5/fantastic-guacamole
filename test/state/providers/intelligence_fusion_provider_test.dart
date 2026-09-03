import 'dart:async';

import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_fusion_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fusion selects all operating modes from local evidence', () {
    final List<
      ({
        TrajectorySummaryView trajectory,
        ExecutionSignals signals,
        IntelligenceOperatingMode mode,
        String label,
      })
    >
    cases =
        <
          ({
            TrajectorySummaryView trajectory,
            ExecutionSignals signals,
            IntelligenceOperatingMode mode,
            String label,
          })
        >[
          (
            trajectory: _trajectory(energy: .3, pressure: 20, momentum: .4),
            signals: _signals(),
            mode: IntelligenceOperatingMode.recovery,
            label: 'Recovery',
          ),
          (
            trajectory: _trajectory(energy: .8, pressure: 30, momentum: .4),
            signals: _signals(skippedToday: 1, delayedToday: 1),
            mode: IntelligenceOperatingMode.stabilization,
            label: 'Stabilization',
          ),
          (
            trajectory: _trajectory(energy: .8, pressure: 40, momentum: .8),
            signals: _signals(completed7d: 4),
            mode: IntelligenceOperatingMode.acceleration,
            label: 'Acceleration',
          ),
          (
            trajectory: _trajectory(energy: .8, pressure: 55, momentum: .5),
            signals: _signals(completed7d: 2),
            mode: IntelligenceOperatingMode.execution,
            label: 'Execution',
          ),
        ];

    for (final item in cases) {
      final ProviderContainer container = _container(
        trajectory: item.trajectory,
        signals: item.signals,
      );
      addTearDown(container.dispose);
      final IntelligenceFusionState result = container.read(
        intelligenceFusionProvider,
      );
      expect(result.mode, item.mode);
      expect(result.operatingMode, item.label);
      expect(result.evidence, hasLength(4));
      expect(result.confidence, inInclusiveRange(0, 1));
    }
  });

  test(
    'fusion prefers governed decision, risk, rationale, and coverage',
    () async {
      final DateTime now = DateTime.utc(2026, 9, 3, 12);
      final OperatingSnapshot snapshot = OperatingSnapshot(
        accountScope: 'v2.test',
        observedAt: now,
        sourceRevisions: const <String, String>{'tasks': 'r1'},
        activeGoalCount: 1,
        actionableCount: 2,
        overdueCount: 1,
        completedToday: 2,
        energy: .6,
        fatigue: .4,
        momentum: 60,
        pressure: 70,
        topActionId: 'task-a',
        topActionLabel: 'Start task A',
        activeRisks: const <String>['Deadline pressure is elevated.'],
        evidenceCoverage: .9,
      );
      final OperatingDecisionReceipt decision = OperatingDecisionReceipt(
        subjectId: 'task-a',
        recommendedAction: 'Start task A',
        rationale: 'It is the highest accountable priority.',
        whyItMatters: 'It protects the deadline.',
        consequenceOfDelay: 'Schedule pressure rises.',
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 20)),
        confidence: OperatingConfidence.high,
        evidence: const <OperatingEvidence>[],
        actionIntent: const OperatingActionIntent(
          id: 'start-task-a',
          type: OperatingActionType.openTimeline,
          label: 'Open timeline',
          destination: '/timeline',
          targetEntityId: 'task-a',
        ),
        sourceRevisions: const <String, String>{'tasks': 'r1'},
        modelVersion: 'test-v1',
      );
      final DecisionIntelligence intelligence = DecisionIntelligence(
        snapshot: snapshot,
        delta: const OperatingDeltaEngine().compare(
          previous: null,
          current: snapshot,
          comparedAt: now,
        ),
        decision: decision,
        acknowledgedSnapshotId: null,
      );
      final ProviderContainer container = _container(
        trajectory: _trajectory(
          energy: .7,
          pressure: 72,
          momentum: .5,
          pendingTasks: 2,
        ),
        signals: _signals(completed7d: 3, skipped7d: 1),
        intelligence: intelligence,
      );
      addTearDown(container.dispose);
      await container.read(decisionIntelligenceProvider.future);

      final IntelligenceFusionState result = container.read(
        intelligenceFusionProvider,
      );
      expect(result.nextAction, 'Start task A');
      expect(result.primaryConstraint, 'Deadline pressure is elevated.');
      expect(result.rationale, 'It is the highest accountable priority.');
      expect(result.confidence, closeTo(.8014, .001));
      expect(result.evidence, contains('coverage=0.900'));
    },
  );

  test('fusion fallbacks distinguish capture, ranking, load, and deferral', () {
    final ProviderContainer capture = _container(
      trajectory: _trajectory(
        energy: .7,
        pressure: 75,
        momentum: .4,
        pendingTasks: 0,
      ),
      signals: _signals(),
    );
    addTearDown(capture.dispose);
    final IntelligenceFusionState captureResult = capture.read(
      intelligenceFusionProvider,
    );
    expect(captureResult.nextAction, contains('Creator'));
    expect(captureResult.primaryConstraint, contains('compressing'));

    final ProviderContainer deferral = _container(
      trajectory: _trajectory(
        energy: .7,
        pressure: 30,
        momentum: .4,
        pendingTasks: 2,
        sourceState: TrajectorySourceState.loading,
      ),
      signals: _signals(skippedToday: 2),
    );
    addTearDown(deferral.dispose);
    final IntelligenceFusionState deferralResult = deferral.read(
      intelligenceFusionProvider,
    );
    expect(deferralResult.nextAction, contains('Smart Planner'));
    expect(deferralResult.primaryConstraint, contains('Repeated deferral'));
    expect(deferralResult.confidence, closeTo(.21, .001));

    final ProviderContainer clear = _container(
      trajectory: _trajectory(
        energy: .7,
        pressure: 30,
        momentum: .4,
        pendingTasks: 1,
      ),
      signals: _signals(),
    );
    addTearDown(clear.dispose);
    expect(
      clear.read(intelligenceFusionProvider).primaryConstraint,
      contains('No material constraint'),
    );
  });
}

ProviderContainer _container({
  required TrajectorySummaryView trajectory,
  required ExecutionSignals signals,
  DecisionIntelligence? intelligence,
}) => ProviderContainer(
  overrides: [
    trajectorySummaryProvider.overrideWithValue(trajectory),
    executionSignalsProvider.overrideWithValue(signals),
    decisionIntelligenceProvider.overrideWith(
      (Ref ref) => intelligence == null
          ? Completer<DecisionIntelligence>().future
          : Future<DecisionIntelligence>.value(intelligence),
    ),
  ],
);

TrajectorySummaryView _trajectory({
  required double energy,
  required int pressure,
  required double momentum,
  int pendingTasks = 1,
  TrajectorySourceState sourceState = TrajectorySourceState.ready,
}) => TrajectorySummaryView(
  pendingTasks: pendingTasks,
  completedTasks: 0,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: energy,
  momentum: momentum,
  adaptability: .5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0,
  pressureIndex: pressure,
  behaviorDivergence: 0,
  alert: 'Local evidence',
  sourceState: sourceState,
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

ExecutionSignals _signals({
  int skippedToday = 0,
  int delayedToday = 0,
  int completed7d = 0,
  int skipped7d = 0,
}) => ExecutionSignals(
  createdToday: 0,
  completedToday: 0,
  skippedToday: skippedToday,
  delayedToday: delayedToday,
  created7d: 0,
  completed7d: completed7d,
  skipped7d: skipped7d,
  delayed7d: 0,
);
