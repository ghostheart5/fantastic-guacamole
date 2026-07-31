import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
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
  });

  final int score;
  final String trend;
  final String recovery;
  final String forecast;
  final int energyPercent;
  final int pressurePercent;
  final int streak;
  final int completedToday;

  bool get isRising => trend == 'Rising';
  bool get isStable => trend == 'Stable';
  bool get isDeclining => trend == 'Declining';
}

final momentumEngineProvider = Provider<MomentumEngineState>((ref) {
  final profile = ref.watch(profileProvider);
  final siState = ref.watch(siStateProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final execution = ref.watch(executionSignalsProvider);
  final habitsAsync = ref.watch(habitsProvider);
  final List<HabitRecord> habits = habitsAsync.maybeWhen(
    data: (items) => items,
    orElse: () => const <HabitRecord>[],
  );

  final int energyPercent = (siState.energy * 100).round().clamp(0, 100);
  final int fatiguePercent = (siState.fatigue * 100).round().clamp(0, 100);
  final int trajectoryMomentum = (trajectory.momentum * 100).round().clamp(
    0,
    100,
  );
  final int streakBoost = (profile.streak * 2).clamp(0, 20);
  final int completionBoost = (siState.completedToday * 6).clamp(0, 24);
  final int executionBoost = (execution.completedToday * 5).clamp(0, 20);
  final int routineBoost = habits.where((habit) => habit.active).length * 2;
  final int deferralPenalty =
      ((execution.skippedToday * 6) + (execution.delayedToday * 4)).clamp(
        0,
        24,
      );
  final int consistencyBonus = (execution.completionStability7d * 12)
      .round()
      .clamp(0, 12);
  final int pressurePenalty = (fatiguePercent * 0.35).round();

  final int score =
      (trajectoryMomentum +
              ((energyPercent * 0.30).round()) +
              streakBoost +
              completionBoost -
              deferralPenalty +
              executionBoost +
                routineBoost +
              consistencyBonus -
              pressurePenalty)
          .clamp(0, 100);

  final String trend = score >= 70
      ? 'Rising'
      : score >= 45
      ? 'Stable'
      : 'Declining';

  final String recovery = fatiguePercent >= 75
      ? 'Recovery Needed'
      : fatiguePercent >= 45
      ? 'Watch Load'
      : 'Recovered';

  final String forecast = score >= 70
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
    pressurePercent: fatiguePercent,
    streak: profile.streak,
    completedToday: siState.completedToday,
  );
});
