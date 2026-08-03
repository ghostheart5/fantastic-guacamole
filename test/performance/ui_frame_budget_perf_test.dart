// ignore_for_file: prefer_const_constructors

import 'dart:ui';

import 'package:fantastic_guacamole/features/auth/ui/login_screen.dart';
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
  group('UI frame budget performance', () {
    testWidgets('login screen pumps within frame budget envelope', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final TextEditingController email = TextEditingController(
        text: 'pilot@chronospark.app',
      );
      final TextEditingController password = TextEditingController(
        text: 'secure-pass-123',
      );
      addTearDown(email.dispose);
      addTearDown(password.dispose);

      final Stopwatch stopwatch = Stopwatch()..start();
      final List<FrameTiming> timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> value) => timings.addAll(value);
      WidgetsBinding.instance.addTimingsCallback(onTimings);
      addTearDown(() => WidgetsBinding.instance.removeTimingsCallback(onTimings));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            emailController: email,
            passwordController: password,
            obscurePassword: true,
            isSubmitting: false,
            isSignUpMode: false,
            onPrimaryAction: () {},
            onForgotPassword: () {},
            onGoogleSignIn: () {},
            onToggleMode: () {},
            onTogglePassword: () {},
          ),
        ),
      );

      for (int i = 0; i < 24; i += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2200));
      _assertFrameTimingsWithinBudget(
        timings: timings,
        maxBuildMs: 20,
        maxRasterMs: 20,
      );
    });

    testWidgets('trajectory engine pumps within frame budget envelope', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final Stopwatch stopwatch = Stopwatch()..start();
      final List<FrameTiming> timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> value) => timings.addAll(value);
      WidgetsBinding.instance.addTimingsCallback(onTimings);
      addTearDown(() => WidgetsBinding.instance.removeTimingsCallback(onTimings));

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
            trajectorySimulationProvider.overrideWithValue(
              const <TrajectorySimulationResult>[
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
              ],
            ),
            futureTimelineProvider.overrideWithValue(
              const FutureTimelineState(
                checkpoints: <FutureTimelineCheckpoint>[
                  FutureTimelineCheckpoint(
                    label: '7 DAYS',
                    days: 7,
                    prediction:
                        'Execution stabilizes if deferrals remain low.',
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

      for (int i = 0; i < 24; i += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2600));
      _assertFrameTimingsWithinBudget(
        timings: timings,
        maxBuildMs: 22,
        maxRasterMs: 22,
      );
    });
  });
}

void _assertFrameTimingsWithinBudget({
  required List<FrameTiming> timings,
  required int maxBuildMs,
  required int maxRasterMs,
}) {
  if (timings.isEmpty) {
    // Some runners do not emit frame timings under test bindings.
    return;
  }

  int worstBuildMs = 0;
  int worstRasterMs = 0;
  for (final FrameTiming timing in timings) {
    final int buildMs = timing.buildDuration.inMilliseconds;
    final int rasterMs = timing.rasterDuration.inMilliseconds;
    if (buildMs > worstBuildMs) {
      worstBuildMs = buildMs;
    }
    if (rasterMs > worstRasterMs) {
      worstRasterMs = rasterMs;
    }
  }

  expect(
    worstBuildMs,
    lessThanOrEqualTo(maxBuildMs),
    reason: 'Worst build time exceeded budget. ms=$worstBuildMs',
  );
  expect(
    worstRasterMs,
    lessThanOrEqualTo(maxRasterMs),
    reason: 'Worst raster time exceeded budget. ms=$worstRasterMs',
  );
}
