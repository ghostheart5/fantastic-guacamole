import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PredictiveRiskLevel { low, medium, high }

class PredictiveRisk {
  const PredictiveRisk({
    required this.title,
    required this.level,
    required this.summary,
    required this.mitigation,
  });

  final String title;
  final PredictiveRiskLevel level;
  final String summary;
  final String mitigation;
}

class PredictiveRiskState {
  const PredictiveRiskState({required this.risks});

  final List<PredictiveRisk> risks;
}

final predictiveRiskProvider = Provider<PredictiveRiskState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);

  final risks = <PredictiveRisk>[
    PredictiveRisk(
      title: 'Momentum Collapse Risk',
      level: momentum.score < 45
          ? PredictiveRiskLevel.high
          : momentum.score < 65
          ? PredictiveRiskLevel.medium
          : PredictiveRiskLevel.low,
      summary: 'Momentum may decline if execution remains inconsistent.',
      mitigation: 'Complete one visible task before opening additional work.',
    ),
    PredictiveRisk(
      title: 'Burnout Risk',
      level: momentum.pressurePercent > 70
          ? PredictiveRiskLevel.high
          : momentum.pressurePercent > 45
          ? PredictiveRiskLevel.medium
          : PredictiveRiskLevel.low,
      summary: 'Pressure load may exceed sustainable operating levels.',
      mitigation: 'Reduce active commitments and schedule recovery.',
    ),
    PredictiveRisk(
      title: 'Trajectory Drift Risk',
      level: momentum.score < 50 && momentum.pressurePercent > 50
          ? PredictiveRiskLevel.high
          : PredictiveRiskLevel.medium,
      summary: 'Current direction may drift away from declared goals.',
      mitigation: 'Review priorities and focus on highest-leverage work.',
    ),
  ];

  return PredictiveRiskState(risks: risks);
});
