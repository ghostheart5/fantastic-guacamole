// CHRONOSPARK-CLASS: SHIPPING | Feature: Trajectory forecasting
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';

/// The forecast engine's uncertainty bounds, in momentum points either side.
const int trajectoryUncertaintyMinimum = 8;
const int trajectoryUncertaintyMaximum = 42;

/// Checked forecasts needed before recorded accuracy changes the ranges.
const int trajectoryCalibrationMinimumForecasts = 3;

/// Distinct local check days needed before recorded accuracy widens the
/// ranges (forecasts checked the same day are checked against one moment).
const int trajectoryCalibrationMinimumCheckDays = 2;

/// Distinct local check days, and the days they must span, before recorded
/// accuracy narrows the ranges. Narrowing needs more evidence than widening.
const int trajectoryCalibrationNarrowingCheckDays = 5;
const int trajectoryCalibrationNarrowingSpanDays = 14;

/// How recorded forecast accuracy changes the forecast ranges.
///
/// Built from a [TrajectoryCalibrationSummary] that uses only checked,
/// uncorrected forecasts of the current model version that were checked in
/// time (a forecast found more than max(1, H / 7) local days after its due
/// day is marked missed and never used). Coverage is the share of those
/// forecasts whose observed pace (momentum) fell inside the engine's own,
/// unadjusted range. The rule:
/// - fewer than 3 checked forecasts, or all of them checked on one local
///   day: x1.0, provisional;
/// - otherwise (3 or more forecasts checked on at least 2 distinct local
///   days), monitored, with:
///   - coverage below 0.6: x1.5 (wider);
///   - coverage 0.6 to below 0.8: x1.2 (wider);
///   - coverage at least 0.9, checked on at least 5 distinct local days
///     whose first and last are at least 14 days apart: x0.85 (narrower);
///   - otherwise x1.0.
/// The adjusted uncertainty is always kept within the engine's bounds
/// (8 to 42).
class TrajectoryCalibrationAdjustment {
  const TrajectoryCalibrationAdjustment({
    required this.multiplier,
    required this.state,
  });

  factory TrajectoryCalibrationAdjustment.fromSummary(
    TrajectoryCalibrationSummary summary,
  ) {
    if (summary.resolvedForecasts < trajectoryCalibrationMinimumForecasts ||
        summary.checkDays < trajectoryCalibrationMinimumCheckDays) {
      return provisional;
    }
    final double coverage = summary.intervalCoverage;
    final bool canNarrow =
        summary.checkDays >= trajectoryCalibrationNarrowingCheckDays &&
        summary.checkSpanDays >= trajectoryCalibrationNarrowingSpanDays;
    final double multiplier = coverage < .6
        ? 1.5
        : coverage < .8
        ? 1.2
        : canNarrow && coverage >= .9
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
