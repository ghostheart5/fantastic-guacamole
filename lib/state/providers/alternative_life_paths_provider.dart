import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_self_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlternativeLifePath {
  const AlternativeLifePath({
    required this.name,
    required this.description,
    required this.tradeoff,
    required this.probability,
  });

  final String name;
  final String description;
  final String tradeoff;
  final int probability;
}

final alternativeLifePathsProvider = Provider<List<AlternativeLifePath>>((ref) {
  final decision = ref.watch(futureDecisionEngineProvider);
  final futures = ref.watch(futureSelfSimulatorProvider);

  return <AlternativeLifePath>[
    AlternativeLifePath(
      name: 'Focused Builder',
      description:
          'Relentlessly executes the highest-leverage work: ${decision.recommendedChoice}.',
      tradeoff: 'Reduced flexibility, greater specialization.',
      probability: futures.isEmpty ? 75 : 82,
    ),

    const AlternativeLifePath(
      name: 'Balanced Operator',
      description: 'Balances execution, recovery, and sustainability.',
      tradeoff: 'Slower gains but lower burnout risk.',
      probability: 76,
    ),

    const AlternativeLifePath(
      name: 'Explorer',
      description: 'Prioritizes experimentation and discovery.',
      tradeoff: 'Lower short-term consistency.',
      probability: 64,
    ),
  ];
});
