import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OpportunityLevel { low, medium, high }

class OpportunityInsight {
  const OpportunityInsight({
    required this.title,
    required this.level,
    required this.summary,
    required this.action,
  });

  final String title;
  final OpportunityLevel level;
  final String summary;
  final String action;
}

class OpportunityEngineState {
  const OpportunityEngineState({required this.opportunities});

  final List<OpportunityInsight> opportunities;
}

final opportunityEngineProvider = Provider<OpportunityEngineState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final success = ref.watch(goalSuccessProbabilityProvider);

  final opportunities = <OpportunityInsight>[
    OpportunityInsight(
      title: 'Momentum Expansion Window',
      level: momentum.score >= 70
          ? OpportunityLevel.high
          : OpportunityLevel.medium,
      summary: 'Momentum conditions support above-average execution.',
      action: 'Use this window to complete a high-impact task.',
    ),

    OpportunityInsight(
      title: 'Goal Completion Acceleration',
      level: success.probability >= 75
          ? OpportunityLevel.high
          : OpportunityLevel.medium,
      summary: 'Current conditions can increase completion probability.',
      action: 'Focus on a single goal and avoid context switching.',
    ),

    OpportunityInsight(
      title: 'Recovery Optimization',
      level: momentum.pressurePercent < 45
          ? OpportunityLevel.high
          : OpportunityLevel.low,
      summary: 'Pressure is low enough to strengthen future sustainability.',
      action: 'Invest in recovery before pressure rises.',
    ),
  ];

  return OpportunityEngineState(opportunities: opportunities);
});
