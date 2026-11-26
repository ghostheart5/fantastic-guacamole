import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
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

final DateTime _selected = DateTime.utc(2026, 11, 1, 12);
int _sequence = 0;

/// A receipt projecting momentum 60 +/- 10. [observedMomentum] inside 50..70
/// is covered by the interval.
TrajectoryForecastReceipt _receipt({
  String modelVersion = trajectoryConsequenceModelVersion,
  int? observedMomentum,
  bool corrected = false,
}) {
  final TrajectoryForecastReceipt receipt = TrajectoryForecastReceipt(
    id: 'receipt-${_sequence++}',
    accountScope: 'v2.test-account',
    baselineRevision: 'trajectory-v4-test',
    scenarioId: 'trajectory-v4-test:maintain-course',
    interventionType: TrajectoryInterventionType.maintainCourse,
    generatedAt: _selected,
    selectedAt: _selected,
    horizon: const Duration(days: 7),
    projectedMomentum: 60,
    projectedPressure: 20,
    uncertainty: 10,
    projectedRiskScore: 30,
    confidenceBand: PredictiveConfidenceBand.moderate,
    modelVersion: modelVersion,
    assumptionsCorrectedAt: corrected
        ? _selected.add(const Duration(days: 1))
        : null,
  );
  if (observedMomentum == null) return receipt;
  return receipt.resolve(
    TrajectoryObservedOutcome(
      observedAt: _selected.add(const Duration(days: 7)),
      momentum: observedMomentum,
      pressure: 20,
      completedInWindow: 5,
      deferredInWindow: 1,
    ),
  );
}

void main() {
  group('the rule does not measure its own output', () {
    test('coverage is judged against the unadjusted width', () {
      // Recorded under x1.5: width 15 covers an error of 12, but the
      // engine's own width (10) does not.
      final TrajectoryForecastReceipt widened = TrajectoryForecastReceipt(
        id: 'widened',
        accountScope: 'v2.test-account',
        baselineRevision: 'trajectory-v4-test',
        scenarioId: 'trajectory-v4-test:maintain-course',
        interventionType: TrajectoryInterventionType.maintainCourse,
        generatedAt: _selected,
        selectedAt: _selected,
        horizon: const Duration(days: 7),
        projectedMomentum: 60,
        projectedPressure: 20,
        uncertainty: 15,
        projectedRiskScore: 30,
        confidenceBand: PredictiveConfidenceBand.moderate,
        modelVersion: trajectoryConsequenceModelVersion,
        calibrationMultiplier: 1.5,
      );
      expect(widened.unadjustedUncertainty, 10);
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
            widened.resolve(
              TrajectoryObservedOutcome(
                observedAt: _selected.add(const Duration(days: 7)),
                momentum: 72,
                pressure: 20,
                completedInWindow: 5,
                deferredInWindow: 1,
              ),
            ),
          ]);
      expect(summary.intervalCoverage, 0);
    });

    test('with a fixed underlying error the multiplier is stable across '
        'successive checks', () {
      final List<TrajectoryForecastReceipt> ledger =
          <TrajectoryForecastReceipt>[];
      final List<double> applied = <double>[];
      for (int week = 0; week < 20; week++) {
        final TrajectoryCalibrationAdjustment rule =
            TrajectoryCalibrationAdjustment.fromSummary(
              TrajectoryCalibrationSummary.fromReceipts(ledger),
            );
        applied.add(rule.multiplier);
        final DateTime selected = _selected.add(Duration(days: 7 * week));
        // The engine's width is 10; the outcome always lands 12 away.
        ledger.add(
          TrajectoryForecastReceipt(
            id: 'week-$week',
            accountScope: 'v2.test-account',
            baselineRevision: 'trajectory-v4-week-$week',
            scenarioId: 'trajectory-v4-week-$week:maintain-course',
            interventionType: TrajectoryInterventionType.maintainCourse,
            generatedAt: selected,
            selectedAt: selected,
            horizon: const Duration(days: 7),
            projectedMomentum: 60,
            projectedPressure: 20,
            uncertainty: rule.apply(10),
            projectedRiskScore: 30,
            confidenceBand: PredictiveConfidenceBand.moderate,
            modelVersion: trajectoryConsequenceModelVersion,
            calibrationMultiplier: rule.multiplier,
          ).resolve(
            TrajectoryObservedOutcome(
              observedAt: selected.add(const Duration(days: 7)),
              momentum: 72,
              pressure: 20,
              completedInWindow: 5,
              deferredInWindow: 1,
            ),
          ),
        );
      }
      expect(applied.take(3), everyElement(1.0));
      expect(applied.skip(3), everyElement(1.5), reason: '$applied');
    });
  });

  group('TrajectoryCalibrationSummary counts like with like', () {
    test('only checked, uncorrected current-version forecasts are used', () {
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
            _receipt(observedMomentum: 60),
            _receipt(observedMomentum: 90),
            // Earlier method: kept, never used, whatever their accuracy.
            _receipt(
              modelVersion: 'trajectory-consequence-v3',
              observedMomentum: 0,
            ),
            _receipt(
              modelVersion: 'trajectory-consequence-v3',
              observedMomentum: 0,
            ),
            _receipt(modelVersion: 'trajectory-consequence-v3'),
            // Assumption-corrected: kept, never used.
            _receipt(observedMomentum: 0, corrected: true),
            // Not yet checked.
            _receipt(),
          ]);
      expect(summary.resolvedForecasts, 2);
      expect(summary.intervalCoverage, .5);
      expect(summary.momentumMeanAbsoluteError, 15);
      expect(summary.earlierMethodForecasts, 3);
      expect(summary.correctedForecasts, 1);
      expect(
        TrajectoryCalibrationAdjustment.fromSummary(summary),
        TrajectoryCalibrationAdjustment.provisional,
      );
    });

    test('earlier-method forecasts do not dilute current coverage', () {
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
            _receipt(observedMomentum: 60),
            _receipt(observedMomentum: 65),
            _receipt(observedMomentum: 0),
            _receipt(observedMomentum: 100),
            for (int i = 0; i < 6; i++)
              _receipt(
                modelVersion: 'trajectory-consequence-v3',
                observedMomentum: 60,
              ),
          ]);
      expect(summary.resolvedForecasts, 4);
      expect(summary.intervalCoverage, .5);
      expect(summary.earlierMethodForecasts, 6);
      final TrajectoryCalibrationAdjustment rule =
          TrajectoryCalibrationAdjustment.fromSummary(summary);
      expect(rule.apply(20), 30);
      expect(rule.state, PredictiveCalibrationState.monitored);
    });

    test('only earlier-method forecasts: nothing used, provisional', () {
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
            for (int i = 0; i < 4; i++)
              _receipt(
                modelVersion: 'trajectory-consequence-v3',
                observedMomentum: 60,
              ),
          ]);
      expect(summary.resolvedForecasts, 0);
      expect(summary.earlierMethodForecasts, 4);
      expect(summary.state, PredictiveCalibrationState.provisional);
    });
  });

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
