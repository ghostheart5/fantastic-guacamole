// CHRONOSPARK-CLASS: SHIPPING | Feature: Trajectory forecasting
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';

/// The forecast engine's uncertainty bounds, in momentum points either side.
const int trajectoryUncertaintyMinimum = 8;
const int trajectoryUncertaintyMaximum = 42;

/// Checked forecasts needed before recorded accuracy widens the ranges.
const int trajectoryCalibrationMinimumForecasts = 3;

/// Checked forecasts needed before recorded accuracy narrows the ranges.
/// Narrowing needs more evidence than widening.
const int trajectoryCalibrationNarrowingForecasts = 5;

/// How recorded forecast accuracy changes the forecast ranges.
///
/// Built from a [TrajectoryCalibrationSummary] that counts only checked,
/// uncorrected forecasts of the current model version:
/// - fewer than 3: x1.0, provisional;
/// - 3 or more with interval coverage below 0.6: x1.5 (wider);
/// - coverage 0.6 to below 0.8: x1.2 (wider);
/// - 5 or more with coverage at least 0.9: x0.85 (narrower);
/// - otherwise x1.0.
/// With 3 or more checked forecasts the state is monitored. The adjusted
/// uncertainty is always kept within the engine's bounds (8 to 42).
class TrajectoryCalibrationAdjustment {
  const TrajectoryCalibrationAdjustment({
    required this.multiplier,
    required this.state,
  });

  factory TrajectoryCalibrationAdjustment.fromSummary(
    TrajectoryCalibrationSummary summary,
  ) {
    final int checked = summary.resolvedForecasts;
    if (checked < trajectoryCalibrationMinimumForecasts) return provisional;
    final double coverage = summary.intervalCoverage;
    final double multiplier = coverage < .6
        ? 1.5
        : coverage < .8
        ? 1.2
        : checked >= trajectoryCalibrationNarrowingForecasts && coverage >= .9
        ? .85
        : 1.0;
    return TrajectoryCalibrationAdjustment(
      multiplier: multiplier,
      state: PredictiveCalibrationState.monitored,
    );
  }

  /// No recorded accuracy is used: the engine's own uncertainty stands.
  static const TrajectoryCalibrationAdjustment provisional =
      TrajectoryCalibrationAdjustment(
        multiplier: 1.0,
        state: PredictiveCalibrationState.provisional,
      );

  final double multiplier;
  final PredictiveCalibrationState state;

  bool get isProvisional => state == PredictiveCalibrationState.provisional;

  /// Feeds the comparison's revision, so a changed rule is a new comparison.
  String get revision => '${state.name}:$multiplier';

  int apply(int uncertainty) => (uncertainty * multiplier).round().clamp(
    trajectoryUncertaintyMinimum,
    trajectoryUncertaintyMaximum,
  );

  @override
  bool operator ==(Object other) =>
      other is TrajectoryCalibrationAdjustment &&
      other.multiplier == multiplier &&
      other.state == state;

  @override
  int get hashCode => Object.hash(multiplier, state);
}
