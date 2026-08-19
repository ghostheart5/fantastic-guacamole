import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GoalSuccessBand { low, medium, high }

class GoalSuccessForecast {
  const GoalSuccessForecast({
    required this.probability,
    required this.band,
    required this.summary,
    required this.recommendation,
    this.lowerBound = 0,
    this.upperBound = 100,
    this.sampleSize = 0,
    this.confidence,
    this.subjectScope = 'portfolio',
  });

  final int probability;
  final GoalSuccessBand band;
  final String summary;
  final String recommendation;
  final int lowerBound;
  final int upperBound;
  final int sampleSize;
  final PredictiveConfidenceProfile? confidence;
  final String subjectScope;
}

final goalSuccessProbabilityProvider = Provider<GoalSuccessForecast>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final execution = ref.watch(executionSignalsProvider);

  final double completionRate = execution.completionRate7d;
  final int probability =
      ((momentum.score * .35) +
              (completionRate * 100 * .40) +
              (momentum.energyPercent * .15) +
              ((100 - momentum.pressurePercent) * .10))
          .round()
          .clamp(0, 100);
  final int sampleSize = execution.actioned7d;
  final double uncertainty = sampleSize == 0
      ? 40
      : (32 / (1 + sampleSize / 4)).clamp(8, 32).toDouble();
  final int lower = (probability - uncertainty).round().clamp(0, 100);
  final int upper = (probability + uncertainty).round().clamp(0, 100);
  final PredictiveConfidenceProfile confidence = PredictiveConfidenceProfile(
    sourceCompleteness: sampleSize > 0 ? .85 : .45,
    freshness: sampleSize > 0 ? 1 : .35,
    sampleSufficiency: (sampleSize / 20).clamp(0.0, 1.0).toDouble(),
    intervalPrecision: (1 - (upper - lower) / 100).clamp(0.0, 1.0),
    calibration: sampleSize >= 30
        ? PredictiveCalibrationState.monitored
        : PredictiveCalibrationState.provisional,
  );

  final GoalSuccessBand band = probability >= 75
      ? GoalSuccessBand.high
      : probability >= 50
      ? GoalSuccessBand.medium
      : GoalSuccessBand.low;

  final String summary = sampleSize < 3
      ? 'There is not enough observed execution history for a strong completion forecast.'
      : probability >= 75
      ? 'Current execution pattern supports goal completion.'
      : probability >= 50
      ? 'Goal completion is possible but execution consistency is needed.'
      : 'Goal is at risk without intervention.';

  final String recommendation = probability >= 75
      ? 'Protect attention and avoid adding new commitments.'
      : probability >= 50
      ? 'Finish one high-impact action daily.'
      : 'Reduce pressure and rebuild momentum before expanding scope.';

  return GoalSuccessForecast(
    probability: probability,
    band: band,
    summary: summary,
    recommendation: recommendation,
    lowerBound: lower,
    upperBound: upper,
    sampleSize: sampleSize,
    confidence: confidence,
  );
});
