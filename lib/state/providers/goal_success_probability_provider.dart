import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GoalSuccessBand { low, medium, high }

class GoalSuccessForecast {
  const GoalSuccessForecast({
    required this.probability,
    required this.band,
    required this.summary,
    required this.recommendation,
  });

  final int probability;
  final GoalSuccessBand band;
  final String summary;
  final String recommendation;
}

final goalSuccessProbabilityProvider = Provider<GoalSuccessForecast>((ref) {
  final momentum = ref.watch(momentumEngineProvider);

  final int probability =
      (momentum.score +
              momentum.energyPercent -
              (momentum.pressurePercent ~/ 2))
          .clamp(0, 100);

  final GoalSuccessBand band = probability >= 75
      ? GoalSuccessBand.high
      : probability >= 50
      ? GoalSuccessBand.medium
      : GoalSuccessBand.low;

  final String summary = probability >= 75
      ? 'Current execution pattern supports goal completion.'
      : probability >= 50
      ? 'Goal completion is possible but execution consistency is needed.'
      : 'Goal is at risk without intervention.';

  final String recommendation = probability >= 75
      ? 'Maintain focus and avoid adding new commitments.'
      : probability >= 50
      ? 'Finish one high-impact action daily.'
      : 'Reduce pressure and rebuild momentum before expanding scope.';

  return GoalSuccessForecast(
    probability: probability,
    band: band,
    summary: summary,
    recommendation: recommendation,
  );
});
