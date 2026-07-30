import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrajectoryDriftLevel { low, medium, high }

class TrajectoryDriftState {
  const TrajectoryDriftState({
    required this.level,
    required this.score,
    required this.summary,
    required this.correction,
  });

  final TrajectoryDriftLevel level;
  final int score;
  final String summary;
  final String correction;
}

final trajectoryDriftProvider = Provider<TrajectoryDriftState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final success = ref.watch(goalSuccessProbabilityProvider);

  final int score =
      (100 -
          momentum.score +
          momentum.pressurePercent +
          (100 - success.probability)) ~/
      3;

  final level = score >= 70
      ? TrajectoryDriftLevel.high
      : score >= 40
      ? TrajectoryDriftLevel.medium
      : TrajectoryDriftLevel.low;

  final String summary = level == TrajectoryDriftLevel.high
      ? 'Current execution pattern is drifting away from projected success.'
      : level == TrajectoryDriftLevel.medium
      ? 'Direction is mostly stable but requires correction.'
      : 'Trajectory is aligned with projected outcomes.';

  final String correction = level == TrajectoryDriftLevel.high
      ? 'Reduce pressure and complete one high-value action immediately.'
      : level == TrajectoryDriftLevel.medium
      ? 'Prioritize focus and protect momentum.'
      : 'Continue the current course.';

  return TrajectoryDriftState(
    level: level,
    score: score.clamp(0, 100),
    summary: summary,
    correction: correction,
  );
});
