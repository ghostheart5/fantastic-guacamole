// ignore_for_file: prefer_const_constructors

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
  group('trajectory engine visual contract', () {
    testWidgets('forecast screen renders planning sections', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trajectorySummaryProvider.overrideWithValue(
              TrajectorySummaryView(
                pendingTasks: 4,
                completedTasks: 3,
                completedToday: 1,
                level: 2,
                streak: 6,
                energy: 0.64,
                momentum: 0.61,
                adaptability: 0.58,
                lastSessionXp: 32,
                lastSessionQuality: 0.72,
                pressureIndex: 43,
                behaviorDivergence: 21,
                alert: 'trajectory stable',
                predictionTitle: 'focus block',
                predictionOutcome:
                    'Trajectory strengthens with focused execution.',
                predictionProbability: 0.74,
                predictionExplanation:
                    'Execution consistency remains the leading factor.',
              ),
            ),
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 71,
                trend: 'Rising',
                recovery: 'Recovered',
                forecast:
                    'Execution quality determines near-term momentum slope.',
                energyPercent: 66,
                pressurePercent: 38,
                streak: 5,
                completedToday: 2,
              ),
            ),
            trajectorySimulationProvider
                .overrideWithValue(const <TrajectorySimulationResult>[
                  TrajectorySimulationResult(
                    type: TrajectorySimulationType.momentumBoost,
                    title: 'Deep Focus Plan',
                    summary: 'Protect one uninterrupted focus block.',
                    projectedMomentum: 84,
                    projectedPressure: 41,
                    projectedRecovery: 'Recovered',
                    projectedOutcome:
                        'Momentum compounds when scope stays narrow.',
                  ),
                ]),
            futureTimelineProvider.overrideWithValue(
              const FutureTimelineState(
                checkpoints: <FutureTimelineCheckpoint>[
                  FutureTimelineCheckpoint(
                    label: '7 DAYS',
                    days: 7,
                    prediction: 'Execution stabilizes if deferrals remain low.',
                  ),
                ],
              ),
            ),
            identityDriftProvider.overrideWithValue(
              const IdentityDriftState(
                alignment: IdentityAlignment.aligned,
                score: 84,
                summary: 'Behavior and direction are aligned.',
                correction: 'Maintain current cadence.',
              ),
            ),
            futureDecisionEngineProvider.overrideWithValue(
              const FutureDecision(
                recommendedChoice: 'Ship the focused milestone block',
                reason: 'Highest alignment path',
                alignmentScore: 84,
              ),
            ),
          ],
          child: const MaterialApp(home: TrajectoryEngineScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      debugPrint(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((Text widget) => widget.data)
            .whereType<String>()
            .join('\n'),
      );

      expect(find.text('Deep Focus Plan'), findsOneWidget);
      expect(find.text('7 DAYS'), findsOneWidget);

      expect(
        find.textContaining('Ship the focused milestone block'),
        findsOneWidget,
      );

      expect(
        find.textContaining('Behavior and direction are aligned.'),
        findsOneWidget,
      );

      expect(find.text('Future Forecast'), findsOneWidget);
      expect(find.text('Outlook'), findsOneWidget);
      expect(find.text('Forecast Guidance'), findsOneWidget);
      expect(find.text('Scenarios'), findsOneWidget);
    });
  });
}
