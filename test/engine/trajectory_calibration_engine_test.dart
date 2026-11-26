import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/trajectory_test_fixture.dart';

/// Every field of every outcome as plain JSON values. Goal dates, days late
/// and goal explanations are built from local calendar fields, so
/// [withGoalDates] false leaves them out (keeping each goal's id, remaining
/// minutes and confidence) so the pinned snapshot does not depend on the
/// machine's time zone.
Map<String, Object?> _structured(
  TrajectoryComparison comparison, {
  bool withGoalDates = true,
}) =>
    jsonDecode(
          jsonEncode(<String, Object?>{
            'recommended': comparison.recommendedScenarioId,
            'outcomes': <Object?>[
              for (final TrajectoryScenarioOutcome o in comparison.outcomes)
                <String, Object?>{
                  'id': o.id,
                  'baselineRevision': o.baselineRevision,
                  'intervention': o.intervention.id,
                  'generatedAt': o.generatedAt.toIso8601String(),
                  'momentum': o.projectedMomentum,
                  'pressure': o.projectedPressure,
                  'uncertainty': o.uncertainty,
                  'calibrationMultiplier': o.calibrationMultiplier,
                  'confidence': o.confidence.toJson(),
                  'risk': <String, Object?>{
                    'current': o.risk.currentScore,
                    'projected': o.risk.projectedScore,
                    'band': o.risk.band.name,
                    'contributions': <Object?>[
                      for (final TrajectoryRiskContribution c
                          in o.risk.contributions)
                        <String, Object?>{
                          'code': c.code,
                          'label': c.label,
                          'current': c.currentScore,
                          'projected': c.projectedScore,
                          'explanation': c.explanation,
                        },
                    ],
                  },
                  'timeline': <String, Object?>{
                    'affectedBlockIds': o.timeline.affectedBlockIds,
                    'displacedSubjectIds': o.timeline.displacedSubjectIds,
                    'deadlineCrossings': o.timeline.deadlineCrossings,
                    'minutesAdded': o.timeline.minutesAdded,
                    'summary': o.timeline.summary,
                  },
                  'goals': <Object?>[
                    for (final GoalDelayProjection g in o.goals)
                      <String, Object?>{
                        'goalId': g.goalId,
                        'goalTitle': g.goalTitle,
                        'remainingMinutes': g.remainingMinutes,
                        'confidence': g.confidence.toJson(),
                        if (withGoalDates) ...<String, Object?>{
                          'targetDate': g.targetDate?.toIso8601String(),
                          'projected': g.projectedCompletion.toIso8601String(),
                          'lower': g.lowerCompletion.toIso8601String(),
                          'upper': g.upperCompletion.toIso8601String(),
                          'delayDays': g.delayDays,
                          'explanation': g.explanation,
                        },
                      },
                  ],
                  'progression': <String, Object?>{
                    'potentialXp': o.progression.potentialXp,
                    'streakProtected': o.progression.streakProtected,
                    'summary': o.progression.summary,
                  },
                  'evidence': o.evidence,
                  'assumptions': o.assumptions,
                  'explanation': o.explanation,
                  'utility': o.utilityScore,
                  'reliefMinutes': o.reliefMinutes,
                  'modelVersion': o.modelVersion,
                },
            ],
          }),
        )
        as Map<String, Object?>;

/// A baseline with little evidence, so its uncertainty is not at a bound
/// at 7 days and reaches the upper bound at 90 days.
TrajectoryBaseline _thinBaseline(int horizonDays) =>
    trajectoryTestBaseline(observationCount: 3, horizonDays: horizonDays);

/// The uncalibrated engine output for the fixtures, without time-zone
/// dependent goal fields.
Map<String, Object?> engineSnapshots() => <String, Object?>{
  for (final int days in const <int>[7, 30, 90])
    'fixture-$days': _structured(
      trajectoryTestComparison(
        horizonDays: days,
        baseline: trajectoryTestBaseline(horizonDays: days),
      ),
      withGoalDates: false,
    ),
  for (final int days in const <int>[7, 90])
    'thin-$days': _structured(
      trajectoryTestComparison(
        horizonDays: days,
        baseline: _thinBaseline(days),
      ),
      withGoalDates: false,
    ),
};

void main() {
  group('the engine without a calibration argument', () {
    test('returns exactly what it returned before', () {
      // Generated from the engine at 8546e962, whose uncalibrated output was
      // checked against the pre-calibration engine (b8483192) by a pinned
      // hash of the same fields.
      // Task 7 changed only one sentence in the fixture ("No Activity reward"
      // became "No progress reward", the screen was renamed); no number moved.
      // Task 8 (review R2) added the new outcome field reliefMinutes to the
      // fixture and to this snapshot (0 for every fixture option: none of
      // them finishes or removes a task); no existing value changed.
      final Object? pinned = jsonDecode(
        File(
          'test/engine/fixtures/trajectory_engine_uncalibrated_snapshot.json',
        ).readAsStringSync(),
      );
      expect(engineSnapshots(), pinned);
    });
    test('the fixture uncertainties sit inside and at the bounds', () {
      expect(trajectoryTestComparison().outcomes.first.uncertainty, 15);
      expect(
        trajectoryTestComparison(
          baseline: _thinBaseline(7),
        ).outcomes.first.uncertainty,
        24,
      );
      expect(
        trajectoryTestComparison(
          horizonDays: 90,
          baseline: _thinBaseline(90),
        ).outcomes.first.uncertainty,
        42,
      );
      expect(
        trajectoryTestComparison().outcomes.first.confidence.calibration,
        PredictiveCalibrationState.provisional,
      );
    });
  });

  group('the engine with a calibration argument', () {
    TrajectoryComparison calibrated(
      TrajectoryBaseline baseline,
      TrajectoryCalibrationAdjustment? calibration, {
      int horizonDays = 7,
    }) {
      final TrajectoryComparison plain = trajectoryTestComparison(
        horizonDays: horizonDays,
        baseline: baseline,
      );
      return const FutureConsequenceEngine().compare(
        baseline: baseline,
        generatedAt: trajectoryFixtureNow,
        interventions: plain.outcomes
            .map((TrajectoryScenarioOutcome o) => o.intervention)
            .toList(growable: false),
        calibration: calibration,
      );
    }

    test('null and provisional give the same outcomes as no argument', () {
      final TrajectoryBaseline baseline = _thinBaseline(7);
      final Map<String, Object?> plain = _structured(
        trajectoryTestComparison(baseline: baseline),
      );
      expect(_structured(calibrated(baseline, null)), plain);
      expect(
        _structured(
          calibrated(baseline, TrajectoryCalibrationAdjustment.provisional),
        ),
        plain,
      );
    });

    test('a widening rule widens every range and marks it monitored', () {
      final TrajectoryBaseline baseline = _thinBaseline(7);
      final TrajectoryComparison plain = trajectoryTestComparison(
        baseline: baseline,
      );
      final TrajectoryComparison wider = calibrated(
        baseline,
        const TrajectoryCalibrationAdjustment(
          multiplier: 1.5,
          state: PredictiveCalibrationState.monitored,
        ),
      );
      for (final TrajectoryScenarioOutcome before in plain.outcomes) {
        final TrajectoryScenarioOutcome after = wider.outcomes.firstWhere(
          (TrajectoryScenarioOutcome o) => o.id == before.id,
        );
        expect(before.uncertainty, 24);
        expect(after.uncertainty, 36);
        expect(after.projectedMomentum, before.projectedMomentum);
        expect(after.projectedPressure, before.projectedPressure);
        expect(
          after.confidence.calibration,
          PredictiveCalibrationState.monitored,
        );
        expect(
          after.confidence.intervalPrecision,
          closeTo(1 - 36 * 2 / 100, 1e-9),
        );
        for (final GoalDelayProjection goal in after.goals) {
          expect(
            goal.confidence.calibration,
            PredictiveCalibrationState.monitored,
          );
        }
      }
    });

    test('a narrowing rule narrows, within the bounds', () {
      final TrajectoryComparison narrower = calibrated(
        trajectoryTestBaseline(),
        const TrajectoryCalibrationAdjustment(
          multiplier: .85,
          state: PredictiveCalibrationState.monitored,
        ),
      );
      expect(narrower.outcomes.first.uncertainty, 13);
    });

    test('the upper bound holds', () {
      final TrajectoryComparison wider = calibrated(
        _thinBaseline(90),
        const TrajectoryCalibrationAdjustment(
          multiplier: 1.5,
          state: PredictiveCalibrationState.monitored,
        ),
        horizonDays: 90,
      );
      expect(wider.outcomes.first.uncertainty, 42);
    });

    test('project takes the same argument', () {
      final TrajectoryBaseline baseline = _thinBaseline(7);
      final TrajectoryIntervention keepGoing = trajectoryTestComparison(
        baseline: baseline,
      ).outcomes.first.intervention;
      expect(
        const FutureConsequenceEngine()
            .project(
              baseline: baseline,
              intervention: keepGoing,
              generatedAt: trajectoryFixtureNow,
              calibration: const TrajectoryCalibrationAdjustment(
                multiplier: 1.2,
                state: PredictiveCalibrationState.monitored,
              ),
            )
            .uncertainty,
        29,
      );
    });
  });
}
