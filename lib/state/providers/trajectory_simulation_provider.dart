import 'package:fantastic_guacamole/state/providers/daily_command_briefing_provider.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrajectorySimulationType {
  momentumBoost,
  recoveryPlan,
  deepFocusPlan,
  goalReduction,
  driftWarning,
}

class TrajectorySimulationResult {
  const TrajectorySimulationResult({
    required this.type,
    required this.title,
    required this.summary,
    required this.projectedMomentum,
    required this.projectedPressure,
    required this.projectedRecovery,
    required this.projectedOutcome,
  });

  final TrajectorySimulationType type;
  final String title;
  final String summary;
  final int projectedMomentum;
  final int projectedPressure;
  final String projectedRecovery;
  final String projectedOutcome;
}

final trajectorySimulationProvider = Provider<List<TrajectorySimulationResult>>((
  ref,
) {
  final momentum = ref.watch(momentumEngineProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final briefing = ref.watch(dailyCommandBriefingProvider);
  final replans = ref.watch(adaptiveReplanningProvider);

  final int baseMomentum = momentum.score;
  final int basePressure = momentum.pressurePercent;

  int clampScore(int value) => value.clamp(0, 100);

  return <TrajectorySimulationResult>[
    if (replans.isNotEmpty)
      TrajectorySimulationResult(
        type: TrajectorySimulationType.recoveryPlan,
        title: 'Adaptive Replan',
        summary: replans.first.summary,
        projectedMomentum: clampScore(baseMomentum + 8),
        projectedPressure: clampScore(basePressure - 10),
        projectedRecovery: replans.first.recoveryMove,
        projectedOutcome: replans.first.dailyAdjustment,
      ),
    TrajectorySimulationResult(
      type: TrajectorySimulationType.momentumBoost,
      title: 'Momentum Boost',
      summary: 'If you complete one high-impact action today.',
      projectedMomentum: clampScore(baseMomentum + 12),
      projectedPressure: clampScore(basePressure + 4),
      projectedRecovery: momentum.recovery,
      projectedOutcome:
          'Momentum rises if execution stays focused and the next move remains narrow.',
    ),
    TrajectorySimulationResult(
      type: TrajectorySimulationType.recoveryPlan,
      title: 'Recovery Plan',
      summary: 'If you reduce pressure before adding more work.',
      projectedMomentum: clampScore(baseMomentum + 6),
      projectedPressure: clampScore(basePressure - 18),
      projectedRecovery: 'Recovered',
      projectedOutcome:
          'Pressure drops and the system becomes more stable for tomorrow.',
    ),
    TrajectorySimulationResult(
      type: TrajectorySimulationType.deepFocusPlan,
      title: 'Deep Focus Plan',
      summary: 'If you protect one focused execution block.',
      projectedMomentum: clampScore(baseMomentum + 16),
      projectedPressure: clampScore(basePressure + 2),
      projectedRecovery: momentum.recovery,
      projectedOutcome:
          'A focused block creates the strongest near-term upward trajectory.',
    ),
    TrajectorySimulationResult(
      type: TrajectorySimulationType.goalReduction,
      title: 'Goal Reduction',
      summary: 'If you reduce active commitments and simplify the system.',
      projectedMomentum: clampScore(baseMomentum + 9),
      projectedPressure: clampScore(basePressure - 12),
      projectedRecovery: basePressure >= 55 ? 'Watch Load' : momentum.recovery,
      projectedOutcome:
          'Simplifying active commitments improves clarity and lowers drift risk.',
    ),
    TrajectorySimulationResult(
      type: TrajectorySimulationType.driftWarning,
      title: 'Drift Warning',
      summary: 'If no meaningful action is completed today.',
      projectedMomentum: clampScore(baseMomentum - 14),
      projectedPressure: clampScore(basePressure + 10),
      projectedRecovery: basePressure >= 60
          ? 'Recovery Needed'
          : momentum.recovery,
      projectedOutcome: trajectory.alert.isNotEmpty
          ? trajectory.alert
          : 'Momentum weakens and tomorrow starts with higher resistance. ${briefing.warning}',
    ),
  ];
});
