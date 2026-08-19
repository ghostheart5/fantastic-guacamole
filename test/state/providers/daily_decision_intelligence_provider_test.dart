import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the evidence-backed decision instead of generic threshold copy',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final OperatingSnapshot snapshot = OperatingSnapshot(
        accountScope: 'account-a',
        observedAt: now,
        sourceRevisions: const <String, String>{'tasks': '4', 'timeline': '3'},
        activeGoalCount: 2,
        actionableCount: 4,
        overdueCount: 1,
        completedToday: 2,
        energy: .63,
        fatigue: .28,
        momentum: 68,
        pressure: 54,
        topActionId: 'task-4',
        topActionLabel: 'Finish the release evidence',
        activeRisks: const <String>['One deadline is overdue.'],
        evidenceCoverage: .82,
      );
      final OperatingDecisionReceipt decision = OperatingDecisionReceipt(
        subjectId: 'task-4',
        recommendedAction: 'Finish the release evidence',
        rationale:
            'It is the highest-ranked feasible action before the deadline.',
        whyItMatters: 'It removes the current schedule bottleneck.',
        consequenceOfDelay: 'The release window becomes less flexible.',
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 20)),
        confidence: OperatingConfidence.high,
        evidence: <OperatingEvidence>[
          OperatingEvidence(
            code: 'ranked_action',
            description: 'Task rank includes deadline, capacity, and energy.',
            kind: OperatingEvidenceKind.derived,
            recordedAt: now,
            source: 'predictive_planning_v2',
            subjectId: 'task-4',
          ),
        ],
        actionIntent: const OperatingActionIntent(
          id: 'open-task-4',
          type: OperatingActionType.openTimeline,
          label: 'Review on Timeline',
          destination: '/timeline',
          targetEntityId: 'task-4',
        ),
        sourceRevisions: const <String, String>{'tasks': '4', 'timeline': '3'},
        modelVersion: 'predictive-planning-v2',
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
      final ProviderContainer container = ProviderContainer(
        overrides: [
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 68,
              trend: 'Rising',
              recovery: 'Recovered',
              forecast: 'Observed momentum is rising.',
              energyPercent: 63,
              pressurePercent: 54,
              streak: 5,
              completedToday: 2,
            ),
          ),
          adaptiveReplanningProvider.overrideWithValue(
            const <AdaptiveReplanningScenario>[],
          ),
          executionSignalsProvider.overrideWithValue(
            const ExecutionSignals(
              createdToday: 1,
              completedToday: 2,
              skippedToday: 0,
              delayedToday: 0,
              created7d: 6,
              completed7d: 5,
              skipped7d: 1,
              delayed7d: 0,
            ),
          ),
          trajectorySummaryProvider.overrideWithValue(
            const TrajectorySummaryView(
              pendingTasks: 4,
              completedTasks: 7,
              completedToday: 2,
              level: 3,
              streak: 5,
              energy: .63,
              momentum: .68,
              adaptability: .7,
              lastCompletionXp: 40,
              lastCompletionQuality: .8,
              pressureIndex: 54,
              behaviorDivergence: 9,
              alert: 'Current evidence is stable.',
              predictionTitle: null,
              predictionOutcome: null,
              predictionProbability: null,
              predictionExplanation: null,
            ),
          ),
          decisionIntelligenceProvider.overrideWith(
            (Ref ref) async => intelligence,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(decisionIntelligenceProvider.future);
      final DailyDecisionIntelligence result = container.read(
        dailyDecisionIntelligenceProvider,
      );

      expect(result.recommendedAction, 'Finish the release evidence');
      expect(result.rationale, contains('highest-ranked feasible action'));
      expect(
        result.evidence,
        contains('Task rank includes deadline, capacity, and energy.'),
      );
      expect(result.confidence, .82);
      expect(result.confidence, lessThan(1));
      expect(result.observedOutcomes, 6);
    },
  );
}
