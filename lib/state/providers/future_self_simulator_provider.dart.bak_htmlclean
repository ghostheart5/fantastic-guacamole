import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_fusion_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FutureSelfSimulation {
  const FutureSelfSimulation({
    required this.name,
    required this.days,
    required this.outcome,
    required this.identityShift,
    required this.description,
  });

  final String name;
  final int days;
  final String outcome;
  final String identityShift;
  final String description;
}

final futureSelfSimulatorProvider = Provider<List<FutureSelfSimulation>>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final fusion = ref.watch(intelligenceFusionProvider);

  return <FutureSelfSimulation>[
    FutureSelfSimulation(
      name: 'Maintain Current Course',
      days: 30,
      outcome: '${fusion.successForecast} ${twin.bestAction}',
      identityShift: 'Execution Consistency',
      description:
          'Continue acting on the current next action with minimal deviation.',
    ),

    const FutureSelfSimulation(
      name: 'Accelerated Focus',
      days: 30,
      outcome: 'Higher probability of goal completion.',
      identityShift: 'Deep Work Operator',
      description:
          'Protect focus daily and execute high-leverage actions only.',
    ),

    const FutureSelfSimulation(
      name: 'Recovery First',
      days: 30,
      outcome: 'Lower pressure and improved sustainability.',
      identityShift: 'Sustainable Performer',
      description: 'Prioritize recovery before expansion and reduce overload.',
    ),
  ];
});
