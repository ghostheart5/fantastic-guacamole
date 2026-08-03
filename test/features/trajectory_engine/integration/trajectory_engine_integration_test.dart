import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> scrollUntilFound(
    WidgetTester tester,
    Finder finder,
  ) async {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  group('trajectory engine integration flow', () {
    testWidgets('renders trajectory surfaces from provider overrides', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildHarness(
          trajectory: _trajectory(pressure: 42, divergence: 18, completed: 7),
          momentum: _momentum(score: 73, pressure: 36, trend: 'Rising'),
          simulations: <TrajectorySimulationResult>[
            _simulation(
              title: 'Deep Focus Plan',
              summary: 'Protect one uninterrupted focus block.',
              momentum: 88,
              pressure: 40,
              recovery: 'Recovered',
              outcome: 'Trajectory strengthens with focused execution.',
            ),
          ],
          timeline: const FutureTimelineState(
            checkpoints: <FutureTimelineCheckpoint>[
              FutureTimelineCheckpoint(
                label: '7 DAYS',
                days: 7,
                prediction: 'Execution stabilizes if deferrals remain low.',
              ),
            ],
          ),
          drift: const IdentityDriftState(
            alignment: IdentityAlignment.aligned,
            score: 84,
            summary: 'Behavior and direction are aligned.',
            correction: 'Maintain current cadence.',
          ),
          decision: const FutureDecision(
            recommendedChoice: 'Ship the focused milestone block',
            reason: 'Highest alignment path',
            alignmentScore: 84,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Future Forecast'), findsOneWidget);
      expect(
        find.textContaining(
          'focused execution',
          skipOffstage: false,
        ),
        findsWidgets,
      );
      await scrollUntilFound(tester, find.text('Deep Focus Plan'));
      expect(find.text('Deep Focus Plan'), findsOneWidget);
      expect(find.text('Momentum: 88%'), findsOneWidget);
      expect(find.text('Decision: Ship the focused milestone block'), findsOneWidget);
      expect(find.textContaining('Alignment 84% -'), findsOneWidget);
    });

    testWidgets('scenario section reflects provided scenario set and projection values', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildHarness(
          trajectory: _trajectory(pressure: 61, divergence: 33, completed: 3),
          momentum: _momentum(score: 51, pressure: 64, trend: 'Stable'),
          simulations: <TrajectorySimulationResult>[
            _simulation(
              title: 'Momentum Boost',
              summary: 'Complete one decisive action today.',
              momentum: 63,
              pressure: 68,
              recovery: 'Watch Load',
              outcome: 'Momentum climbs if execution remains narrow.',
            ),
            _simulation(
              title: 'Recovery Plan',
              summary: 'Lower pressure before adding new commitments.',
              momentum: 58,
              pressure: 49,
              recovery: 'Recovered',
              outcome: 'Pressure drops and next-day readiness improves.',
            ),
          ],
          timeline: const FutureTimelineState(checkpoints: <FutureTimelineCheckpoint>[]),
          drift: const IdentityDriftState(
            alignment: IdentityAlignment.drifting,
            score: 61,
            summary: 'Small drift detected.',
            correction: 'Reduce active scope.',
          ),
          decision: const FutureDecision(
            recommendedChoice: 'Reduce active commitments',
            reason: 'Pressure reduction path',
            alignmentScore: 61,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await scrollUntilFound(tester, find.text('Momentum Boost'));
      expect(find.text('Momentum Boost'), findsOneWidget);
      expect(find.text('Recovery Plan'), findsOneWidget);
      expect(find.text('Pressure: 68%'), findsOneWidget);
      expect(find.text('Pressure: 49%'), findsOneWidget);
      expect(find.text('Recovery: Watch Load'), findsAtLeastNWidgets(1));
      expect(find.text('Recovery: Recovered'), findsOneWidget);
    });

    testWidgets('forecast guidance updates when trajectory risk signal changes', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget buildWithAlert(String alert) {
        return _buildHarness(
          trajectory: _trajectory(
            pressure: 76,
            divergence: 47,
            completed: 2,
            alert: alert,
            outcome: 'Near-term path is sensitive to execution quality.',
          ),
          momentum: _momentum(score: 44, pressure: 74, trend: 'Declining'),
          simulations: <TrajectorySimulationResult>[
            _simulation(
              title: 'Drift Warning',
              summary: 'No meaningful action completed today.',
              momentum: 30,
              pressure: 84,
              recovery: 'Recovery Needed',
              outcome: 'Momentum weakens and pressure rises.',
            ),
          ],
          timeline: const FutureTimelineState(checkpoints: <FutureTimelineCheckpoint>[]),
          drift: const IdentityDriftState(
            alignment: IdentityAlignment.diverging,
            score: 38,
            summary: 'Direction is diverging.',
            correction: 'Re-center with one decisive completion.',
          ),
          decision: const FutureDecision(
            recommendedChoice: 'Stabilize load immediately',
            reason: 'Risk mitigation path',
            alignmentScore: 38,
          ),
        );
      }

      await tester.pumpWidget(buildWithAlert('risk detected in current trajectory'));
      await tester.pump(const Duration(milliseconds: 500));

      await scrollUntilFound(
        tester,
        find.textContaining('Some risk signals are active'),
      );
      expect(
        find.textContaining('Some risk signals are active'),
        findsOneWidget,
      );

      await tester.pumpWidget(buildWithAlert('stable trajectory state'));
      await tester.pump(const Duration(milliseconds: 500));

      await scrollUntilFound(
        tester,
        find.textContaining('Your current pace supports a positive outcome'),
      );
      expect(
        find.textContaining('Your current pace supports a positive outcome'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildHarness({
  required TrajectorySummaryView trajectory,
  required MomentumEngineState momentum,
  required List<TrajectorySimulationResult> simulations,
  required FutureTimelineState timeline,
  required IdentityDriftState drift,
  required FutureDecision decision,
}) {
  return ProviderScope(
    overrides: [
      trajectorySummaryProvider.overrideWithValue(trajectory),
      momentumEngineProvider.overrideWithValue(momentum),
      trajectorySimulationProvider.overrideWithValue(simulations),
      futureTimelineProvider.overrideWithValue(timeline),
      identityDriftProvider.overrideWithValue(drift),
      futureDecisionEngineProvider.overrideWithValue(decision),
    ],
    child: const MaterialApp(home: TrajectoryEngineScreen()),
  );
}

TrajectorySummaryView _trajectory({
  required int pressure,
  required int divergence,
  required int completed,
  String? alert,
  String? outcome,
}) {
  return TrajectorySummaryView(
    pendingTasks: 4,
    completedTasks: completed,
    completedToday: 1,
    level: 3,
    streak: 6,
    energy: 0.62,
    momentum: 0.58,
    adaptability: 0.66,
    lastSessionXp: 25,
    lastSessionQuality: 0.74,
    pressureIndex: pressure,
    behaviorDivergence: divergence,
    alert: alert ?? 'trajectory stable',
    predictionTitle: 'focus block',
    predictionOutcome: outcome ?? 'Current path remains stable with focused execution.',
    predictionProbability: 0.72,
    predictionExplanation: 'Execution consistency remains the leading factor.',
  );
}

MomentumEngineState _momentum({
  required int score,
  required int pressure,
  required String trend,
}) {
  return MomentumEngineState(
    score: score,
    trend: trend,
    recovery: pressure >= 70
        ? 'Recovery Needed'
        : pressure >= 45
            ? 'Watch Load'
            : 'Recovered',
    forecast: 'Execution quality determines near-term momentum slope.',
    energyPercent: 64,
    pressurePercent: pressure,
    streak: 5,
    completedToday: 2,
  );
}

TrajectorySimulationResult _simulation({
  required String title,
  required String summary,
  required int momentum,
  required int pressure,
  required String recovery,
  required String outcome,
}) {
  return TrajectorySimulationResult(
    type: TrajectorySimulationType.momentumBoost,
    title: title,
    summary: summary,
    projectedMomentum: momentum,
    projectedPressure: pressure,
    projectedRecovery: recovery,
    projectedOutcome: outcome,
  );
}

