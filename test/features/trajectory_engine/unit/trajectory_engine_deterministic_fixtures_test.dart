import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

void main() {
  group('trajectory engine deterministic fixtures', () {
    test('high pressure returns overload-aware replans', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 58, pressure: 82, energy: 61),
      );
      addTearDown(container.dispose);

      final List<AdaptiveReplanningScenario> scenarios = container.read(
        adaptiveReplanningProvider,
      );
      final List<AdaptiveReplanningType> kinds = scenarios
          .map((AdaptiveReplanningScenario item) => item.type)
          .toList(growable: false);

      expect(kinds.contains(AdaptiveReplanningType.overloadedDay), isTrue);
      expect(kinds.contains(AdaptiveReplanningType.lowEnergy), isFalse);
    });

    test('low energy returns low-energy replans', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 56, pressure: 44, energy: 32),
      );
      addTearDown(container.dispose);

      final List<AdaptiveReplanningScenario> scenarios = container.read(
        adaptiveReplanningProvider,
      );

      expect(
        scenarios.any(
          (AdaptiveReplanningScenario item) =>
              item.type == AdaptiveReplanningType.lowEnergy,
        ),
        isTrue,
      );
    });

    test('low momentum returns momentum-recovery scenario set', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 38, pressure: 40, energy: 62),
      );
      addTearDown(container.dispose);

      final List<AdaptiveReplanningScenario> scenarios = container.read(
        adaptiveReplanningProvider,
      );

      expect(
        scenarios.any(
          (AdaptiveReplanningScenario item) =>
              item.type == AdaptiveReplanningType.momentumRecovery,
        ),
        isTrue,
      );
    });

    test('strong momentum uses evidence-neutral course protection', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 78, pressure: 36, energy: 74),
      );
      addTearDown(container.dispose);

      final List<AdaptiveReplanningScenario> scenarios = container.read(
        adaptiveReplanningProvider,
      );

      expect(scenarios.first.title, 'Course Protection');
      expect(scenarios.first.evidence, isNotEmpty);
    });

    test(
      'trajectory simulations include adaptive replan card when replans exist',
      () {
        final ProviderContainer container = _container(
          momentum: _momentum(score: 52, pressure: 58, energy: 54),
        );
        addTearDown(container.dispose);

        final List<TrajectorySimulationResult> results = container.read(
          trajectorySimulationProvider,
        );

        expect(results, isNotEmpty);
        expect(results.first.title, isNotEmpty);
        expect(results.first.summary, isNotEmpty);
      },
    );

    test('simulation projected values are clamped within 0..100', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 97, pressure: 95, energy: 68),
      );
      addTearDown(container.dispose);

      final List<TrajectorySimulationResult> results = container.read(
        trajectorySimulationProvider,
      );

      for (final TrajectorySimulationResult item in results) {
        expect(item.projectedMomentum, inInclusiveRange(0, 100));
        expect(item.projectedPressure, inInclusiveRange(0, 100));
      }
    });

    test('future checkpoints share the revisioned consequence authority', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 61, pressure: 58, energy: 64),
      );
      addTearDown(container.dispose);

      final FutureTimelineState timeline = container.read(
        futureTimelineProvider,
      );

      expect(
        timeline.checkpoints.map((FutureTimelineCheckpoint item) => item.days),
        <int>[7, 30, 90],
      );
      expect(
        timeline.checkpoints,
        everyElement(
          isA<FutureTimelineCheckpoint>().having(
            (FutureTimelineCheckpoint item) => item.evidence,
            'evidence',
            contains('baseline_revision=trajectory-fixture-r1'),
          ),
        ),
      );
      expect(
        timeline.checkpoints.last.classification,
        'Exploratory conditional scenario',
      );
    });

    test('predictive risk uses accumulated consequence contributors', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 61, pressure: 58, energy: 64),
      );
      addTearDown(container.dispose);

      final PredictiveRiskState risk = container.read(predictiveRiskProvider);

      expect(risk.risks, hasLength(4));
      expect(
        risk.risks.expand((PredictiveRisk item) => item.evidenceCodes),
        contains('baseline=trajectory-fixture-r1'),
      );
      expect(
        risk.risks.map((PredictiveRisk item) => item.level),
        isNot(contains(PredictiveRiskLevel.unknown)),
      );
    });

    test('unavailable evidence is unknown instead of low risk', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          trajectoryConsequenceProvider.overrideWithValue(
            const AsyncValue<TrajectoryComparison>.loading(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final PredictiveRiskState risk = container.read(predictiveRiskProvider);

      expect(risk.risks.single.level, PredictiveRiskLevel.unknown);
      expect(
        risk.risks.single.confidence,
        PredictiveConfidenceBand.insufficientEvidence,
      );
    });

    test('delay scenario exposes typed risk and Timeline consequences', () {
      final ProviderContainer container = _container(
        momentum: _momentum(score: 42, pressure: 84, energy: 39),
      );
      addTearDown(container.dispose);

      final List<TrajectorySimulationResult> results = container.read(
        trajectorySimulationProvider,
      );
      final TrajectorySimulationResult delayed = results.firstWhere(
        (TrajectorySimulationResult item) =>
            item.type == TrajectorySimulationType.driftWarning &&
            item.title.contains('Delay'),
      );

      expect(delayed.risk, isNotNull);
      expect(delayed.timeline, isNotNull);
      expect(delayed.timeline!.deadlineCrossings, 1);
      expect(delayed.baselineRevision, 'trajectory-fixture-r1');
      expect(delayed.classification, 'Conditional deterministic scenario');
      expect(delayed.assumptions, contains(contains('unmodeled life events')));
    });
  });
}

ProviderContainer _container({
  required MomentumEngineState momentum,
  TrajectorySummaryView? trajectory,
}) {
  return ProviderContainer(
    overrides: [
      momentumEngineProvider.overrideWithValue(momentum),
      trajectorySummaryProvider.overrideWithValue(
        trajectory ?? _trajectory(alert: 'SI ALERT: trajectory is calm.'),
      ),
      trajectoryConsequenceProvider.overrideWithValue(
        AsyncValue<TrajectoryComparison>.data(trajectoryTestComparison()),
      ),
    ],
  );
}

MomentumEngineState _momentum({
  required int score,
  required int pressure,
  required int energy,
}) {
  return MomentumEngineState(
    score: score,
    trend: score >= 70
        ? 'Rising'
        : score >= 45
        ? 'Stable'
        : 'Declining',
    recovery: pressure >= 75
        ? 'Recovery Needed'
        : pressure >= 45
        ? 'Watch Load'
        : 'Recovered',
    forecast: 'Deterministic fixture forecast.',
    energyPercent: energy,
    pressurePercent: pressure,
    streak: 4,
    completedToday: 2,
  );
}

TrajectorySummaryView _trajectory({required String alert}) {
  return TrajectorySummaryView(
    pendingTasks: 3,
    completedTasks: 5,
    completedToday: 2,
    level: 3,
    streak: 4,
    energy: 0.61,
    momentum: 0.57,
    adaptability: 0.63,
    lastCompletionXp: 18,
    lastCompletionQuality: 0.72,
    pressureIndex: 52,
    behaviorDivergence: 21,
    alert: alert,
    predictionTitle: 'attention',
    predictionOutcome: 'Stable path.',
    predictionProbability: 0.67,
    predictionExplanation: 'Steady signal.',
  );
}
