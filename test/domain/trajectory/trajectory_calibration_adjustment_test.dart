import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

TrajectoryCalibrationSummary _summary(int resolved, double coverage) =>
    TrajectoryCalibrationSummary(
      resolvedForecasts: resolved,
      momentumMeanAbsoluteError: 0,
      pressureMeanAbsoluteError: 0,
      intervalCoverage: coverage,
      state: resolved == 0
          ? PredictiveCalibrationState.provisional
          : PredictiveCalibrationState.monitored,
    );

TrajectoryCalibrationAdjustment _rule(int resolved, double coverage) =>
    TrajectoryCalibrationAdjustment.fromSummary(_summary(resolved, coverage));

void main() {
  group('TrajectoryCalibrationAdjustment', () {
    test('the bounds are the engine bounds, 8 to 42', () {
      expect(trajectoryUncertaintyMinimum, 8);
      expect(trajectoryUncertaintyMaximum, 42);
    });

    test('2 checked forecasts: uncertainty unchanged, provisional', () {
      final TrajectoryCalibrationAdjustment rule = _rule(2, 0);
      expect(rule.multiplier, 1.0);
      expect(rule.state, PredictiveCalibrationState.provisional);
      expect(rule.apply(20), 20);
      expect(rule, TrajectoryCalibrationAdjustment.provisional);
    });

    test('4 checked forecasts with coverage 0.5: 20 becomes 30, monitored', () {
      final TrajectoryCalibrationAdjustment rule = _rule(4, .5);
      expect(rule.multiplier, 1.5);
      expect(rule.state, PredictiveCalibrationState.monitored);
      expect(rule.apply(20), 30);
    });

    test('3 checked forecasts with coverage 0.7: 20 becomes 24', () {
      final TrajectoryCalibrationAdjustment rule = _rule(3, .7);
      expect(rule.multiplier, 1.2);
      expect(rule.state, PredictiveCalibrationState.monitored);
      expect(rule.apply(20), 24);
    });

    test('6 checked forecasts with coverage 1.0: 20 becomes 17', () {
      final TrajectoryCalibrationAdjustment rule = _rule(6, 1);
      expect(rule.multiplier, .85);
      expect(rule.state, PredictiveCalibrationState.monitored);
      expect(rule.apply(20), 17);
    });

    test('band edges: 0.6 and 0.8 belong to the higher band', () {
      expect(_rule(5, 3 / 5).multiplier, 1.2);
      expect(_rule(5, 4 / 5).multiplier, 1.0);
      expect(_rule(10, 9 / 10).multiplier, .85);
      expect(_rule(10, .89).multiplier, 1.0);
    });

    test('narrowing needs 5 checked forecasts; widening needs only 3', () {
      expect(_rule(4, 1).multiplier, 1.0);
      expect(_rule(4, 1).state, PredictiveCalibrationState.monitored);
      expect(_rule(5, 1).multiplier, .85);
      expect(_rule(3, 0).multiplier, 1.5);
      expect(_rule(3, .67).multiplier, 1.2);
    });

    test('results are clamped to the engine bounds', () {
      expect(_rule(4, 0).apply(40), 42);
      expect(_rule(4, 0).apply(42), 42);
      expect(_rule(9, 1).apply(8), 8);
      expect(_rule(9, 1).apply(9), 8);
      expect(TrajectoryCalibrationAdjustment.provisional.apply(42), 42);
    });

    test('equal rules are equal and carry a stable revision', () {
      expect(_rule(4, .5), _rule(3, .1));
      expect(_rule(4, .5).hashCode, _rule(3, .1).hashCode);
      expect(_rule(4, .5), isNot(_rule(4, .7)));
      expect(_rule(4, .5).revision, 'monitored:1.5');
      expect(
        TrajectoryCalibrationAdjustment.provisional.revision,
        'provisional:1.0',
      );
    });
  });
}
