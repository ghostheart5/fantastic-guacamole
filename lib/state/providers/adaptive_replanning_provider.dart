import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdaptiveReplanningType {
  missedMorning,
  overloadedDay,
  lowEnergy,
  momentumRecovery,
}

class AdaptiveReplanningScenario {
  const AdaptiveReplanningScenario({
    required this.type,
    required this.title,
    required this.summary,
    required this.immediateAction,
    required this.recoveryMove,
    required this.dailyAdjustment,
    required this.moves,
  });

  final AdaptiveReplanningType type;
  final String title;
  final String summary;
  final String immediateAction;
  final String recoveryMove;
  final String dailyAdjustment;
  final List<String> moves;
}

final adaptiveReplanningProvider = Provider<List<AdaptiveReplanningScenario>>((
  ref,
) {
  final momentum = ref.watch(momentumEngineProvider);

  final bool pressureHigh = momentum.pressurePercent >= 70;
  final bool energyLow = momentum.energyPercent < 45;
  final bool momentumLow = momentum.score < 45;
  final bool momentumStrong = momentum.score >= 70;

  final List<AdaptiveReplanningScenario>
  scenarios = <AdaptiveReplanningScenario>[
    const AdaptiveReplanningScenario(
      type: AdaptiveReplanningType.missedMorning,
      title: 'Missed Morning Recovery',
      summary:
          'If the day starts late, compress the plan into one recovery win and one high-impact move.',
      immediateAction:
          'Pick one task that can be completed in under 20 minutes.',
      recoveryMove:
          'Use a small completion to restore rhythm before heavy work.',
      dailyAdjustment:
          'Drop nonessential work and protect the next available execution window.',
      moves: <String>[
        'Choose one light recovery task.',
        'Move low-priority work out of today.',
        'Restart with one clear block.',
      ],
    ),
    const AdaptiveReplanningScenario(
      type: AdaptiveReplanningType.overloadedDay,
      title: 'Overloaded Day Reduction',
      summary:
          'If pressure is high, reduce active scope before attempting more execution.',
      immediateAction: 'Remove or defer one commitment immediately.',
      recoveryMove: 'Lower pressure before adding new tasks.',
      dailyAdjustment:
          'Shift the day from expansion mode into stabilization mode.',
      moves: <String>[
        'Defer one low-impact task.',
        'Keep only the highest-leverage action.',
        'Protect recovery time before the next work block.',
      ],
    ),
    const AdaptiveReplanningScenario(
      type: AdaptiveReplanningType.lowEnergy,
      title: 'Low Energy Rebuild',
      summary:
          'If energy is low, rebuild momentum through an easy win before deep work.',
      immediateAction: 'Start with the smallest useful action available.',
      recoveryMove: 'Use completion, not intensity, to restart the system.',
      dailyAdjustment:
          'Convert heavy work into one smaller, finishable checkpoint.',
      moves: <String>[
        'Choose one easy win.',
        'Reduce the next task to its first step.',
        'Avoid major planning until energy stabilizes.',
      ],
    ),
    const AdaptiveReplanningScenario(
      type: AdaptiveReplanningType.momentumRecovery,
      title: 'Momentum Recovery Path',
      summary:
          'If momentum is declining, the best move is a narrow action with visible completion.',
      immediateAction: 'Complete one clear task before opening new loops.',
      recoveryMove: 'Recover confidence through one finished action.',
      dailyAdjustment:
          'Limit context switching and keep the next move obvious.',
      moves: <String>[
        'Finish one open loop.',
        'Avoid starting another large task.',
        'Review the next action after completion.',
      ],
    ),
  ];

  if (pressureHigh) {
    return scenarios
        .where(
          (AdaptiveReplanningScenario item) =>
              item.type == AdaptiveReplanningType.overloadedDay ||
              item.type == AdaptiveReplanningType.missedMorning ||
              item.type == AdaptiveReplanningType.momentumRecovery,
        )
        .toList(growable: false);
  }

  if (energyLow) {
    return scenarios
        .where(
          (AdaptiveReplanningScenario item) =>
              item.type == AdaptiveReplanningType.lowEnergy ||
              item.type == AdaptiveReplanningType.missedMorning ||
              item.type == AdaptiveReplanningType.momentumRecovery,
        )
        .toList(growable: false);
  }

  if (momentumLow) {
    return scenarios
        .where(
          (AdaptiveReplanningScenario item) =>
              item.type == AdaptiveReplanningType.momentumRecovery ||
              item.type == AdaptiveReplanningType.lowEnergy ||
              item.type == AdaptiveReplanningType.missedMorning,
        )
        .toList(growable: false);
  }

  if (momentumStrong) {
    return <AdaptiveReplanningScenario>[
      const AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.momentumRecovery,
        title: 'High Momentum Protection',
        summary:
            'Momentum is strong. Protect focus and avoid scattering the system.',
        immediateAction: 'Execute the highest-impact action now.',
        recoveryMove: 'Keep recovery light and do not overload the day.',
        dailyAdjustment:
            'Hold the current direction and avoid unnecessary replanning.',
        moves: <String>[
          'Execute the highest-impact task.',
          'Do not add new commitments.',
          'Preserve one recovery buffer.',
        ],
      ),
      ...scenarios.take(2),
    ];
  }

  return scenarios.take(3).toList(growable: false);
});
