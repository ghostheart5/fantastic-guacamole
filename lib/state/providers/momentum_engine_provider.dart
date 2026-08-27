import 'dart:math' as math;

import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MomentumEngineState {
  const MomentumEngineState({
    required this.score,
    required this.trend,
    required this.recovery,
    required this.forecast,
    required this.energyPercent,
    required this.pressurePercent,
    required this.streak,
    required this.completedToday,
    this.trendDelta,
    this.trendEvidence = 'baseline',
  });

  final int score;
  final String trend;
  final String recovery;
  final String forecast;
  final int energyPercent;
  final int pressurePercent;
  final int streak;
  final int completedToday;
  final double? trendDelta;
  final String trendEvidence;

  bool get isRising => trend == 'Rising';
  bool get isStable => trend == 'Stable';
  bool get isDeclining => trend == 'Declining';
}

final momentumEngineProvider = Provider<MomentumEngineState>((ref) {
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final execution = ref.watch(executionSignalsProvider);
  final int energyPercent = (siState.energy * 100).round().clamp(0, 100);
  final int fatiguePercent = (siState.fatigue * 100).round().clamp(0, 100);
  final int trajectoryMomentum = (trajectory.momentum * 100).round().clamp(
    0,
    100,
  );
  final int pressurePercent = math.max(
    fatiguePercent,
    trajectory.pressureIndex,
  );
  final double executionRate = execution.completionRate7d;
  final double deferralRate = execution.actioned7d == 0
      ? 0
      : (execution.skipped7d + execution.delayed7d) / execution.actioned7d;
  final double streakContinuity = (profile.streak / 14).clamp(0.0, 1.0);
  final int score =
      ((trajectoryMomentum * .25) +
              (energyPercent * .20) +
              (executionRate * 100 * .30) +
              (streakContinuity * 100 * .10) +
              (siState.completedToday.clamp(0, 4) / 4 * 100 * .10) -
              (deferralRate * 100 * .15) -
              (pressurePercent * .10))
          .round()
          .clamp(0, 100);

  final double? trendDelta = execution.completionTrendDelta;
  final String trend = trendDelta == null
      ? 'Stable'
      : trendDelta >= .10
      ? 'Rising'
      : trendDelta <= -.10
      ? 'Declining'
      : 'Stable';

  final String recovery = pressurePercent >= 75
      ? 'Recovery Needed'
      : fatiguePercent >= 45
      ? 'Watch Load'
      : 'Recovered';

  final String forecast = trendDelta == null
      ? 'Momentum baseline established. More history is needed before claiming a direction.'
      : score >= 70
      ? 'Momentum forecast is positive. Execute high-impact work.'
      : score >= 45
      ? 'Momentum is stable. Complete one clear action to build lift.'
      : 'Momentum is low. Choose a light recovery win before heavy work.';

  return MomentumEngineState(
    score: score,
    trend: trend,
    recovery: recovery,
    forecast: forecast,
    energyPercent: energyPercent,
    pressurePercent: pressurePercent,
    streak: profile.streak,
    completedToday: siState.completedToday,
    trendDelta: trendDelta,
    trendEvidence: trendDelta == null
        ? 'No prior seven-day comparison window is available.'
        : 'Compared the current seven-day completion rate with the previous seven days.',
  );
});
