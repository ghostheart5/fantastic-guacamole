import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyCommandBriefing {
  const DailyCommandBriefing({
    required this.primaryAction,
    required this.momentum,
    required this.trajectory,
    required this.energy,
    required this.warning,
    required this.recovery,
    required this.recommendedAction,
    this.replanTitle,
    this.replanAction,
  });

  final String primaryAction;
  final String momentum;
  final String trajectory;
  final String energy;
  final String warning;
  final String recovery;
  final String recommendedAction;
  final String? replanTitle;
  final String? replanAction;
}

final dailyCommandBriefingProvider = Provider<DailyCommandBriefing>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final replans = ref.watch(adaptiveReplanningProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);

  final String primaryAction = momentum.score >= 70
      ? 'Execute high-impact work'
      : momentum.score >= 45
      ? 'Complete one stabilizing action'
      : 'Recover rhythm with one light win';

  final String trajectoryText =
      trajectory.predictionOutcome ?? 'Future path is still stabilizing.';

  final String warning = momentum.pressurePercent >= 75
      ? 'Pressure is high. Reduce load before adding new work.'
      : momentum.pressurePercent >= 45
      ? 'Pressure is moderate. Keep actions focused.'
      : 'Pressure is controlled. Maintain forward motion.';

  final String recovery = momentum.recovery;

  final String recommendedAction = momentum.score >= 70
      ? 'Choose the highest-impact task and execute now.'
      : momentum.score >= 45
      ? 'Pick one clear next move and finish it.'
      : 'Choose a small recovery action before heavy work.';

  return DailyCommandBriefing(
    primaryAction: primaryAction,
    momentum: '${momentum.score}% ${momentum.trend}',
    trajectory: trajectoryText,
    energy: '${momentum.energyPercent}% energy',
    warning: warning,
    recovery: recovery,
    recommendedAction: recommendedAction,
    replanTitle: replans.isEmpty ? null : replans.first.title,
    replanAction: replans.isEmpty ? null : replans.first.immediateAction,
  );
});
