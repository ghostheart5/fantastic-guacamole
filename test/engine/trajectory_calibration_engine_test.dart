import 'dart:convert';

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/trajectory_test_fixture.dart';

/// Every field of every outcome, in order, as one string. Goal dates are
/// built from local calendar fields, so [withGoals] false leaves goals out to
/// keep a pinned value independent of the machine's time zone.
String _snapshot(TrajectoryComparison comparison, {bool withGoals = true}) =>
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
            'confidence': o.confidence.toJson(),
            'risk': <Object?>[
              o.risk.currentScore,
              o.risk.projectedScore,
              o.risk.band.name,
              for (final TrajectoryRiskContribution c in o.risk.contributions)
                <Object?>[
                  c.code,
                  c.label,
                  c.currentScore,
                  c.projectedScore,
                  c.explanation,
                ],
            ],
            'timeline': <Object?>[
              o.timeline.affectedBlockIds,
              o.timeline.displacedSubjectIds,
              o.timeline.deadlineCrossings,
              o.timeline.minutesAdded,
              o.timeline.summary,
            ],
            'goals': <Object?>[
              if (!withGoals) o.goals.length,
              for (final GoalDelayProjection g
                  in withGoals ? o.goals : const [])
                <Object?>[
                  g.goalId,
                  g.goalTitle,
                  g.targetDate?.toIso8601String(),
                  g.projectedCompletion.toIso8601String(),
                  g.lowerCompletion.toIso8601String(),
                  g.upperCompletion.toIso8601String(),
                  g.delayDays,
                  g.remainingMinutes,
                  g.confidence.toJson(),
                  g.explanation,
                ],
            ],
            'progression': <Object?>[
              o.progression.potentialXp,
              o.progression.streakProtected,
              o.progression.summary,
            ],
            'evidence': o.evidence,
            'assumptions': o.assumptions,
            'explanation': o.explanation,
            'utility': o.utilityScore,
            'modelVersion': o.modelVersion,
          },
      ],
    });

/// FNV-1a over the UTF-16 code units, 32-bit, so the pinned value is short.
String _hash(String value) {
  int hash = 0x811c9dc5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// A baseline with little evidence, so its uncertainty is not at a bound
/// at 7 days and reaches the upper bound at 90 days.
TrajectoryBaseline _thinBaseline(int horizonDays) =>
    trajectoryTestBaseline(observationCount: 3, horizonDays: horizonDays);

void main() {
  group('the engine without a calibration argument', () {
    // Pinned on the engine before calibration existed (commit b8483192).
    const Map<String, String> pinned = <String, String>{
      'fixture-7': 'ce9e228e',
      'fixture-30': '90da1c51',
      'fixture-90': 'f7903a7e',
      'thin-7': '159f376f',
      'thin-90': '806da41b',
    };

    test('returns exactly what it returned before', () {
      final Map<String, String> actual = <String, String>{
        for (final int days in const <int>[7, 30, 90])
          'fixture-$days': _hash(
            _snapshot(
              trajectoryTestComparison(
                horizonDays: days,
                baseline: trajectoryTestBaseline(horizonDays: days),
              ),
              withGoals: false,
            ),
          ),
        for (final int days in const <int>[7, 90])
          'thin-$days': _hash(
            _snapshot(
              trajectoryTestComparison(
                horizonDays: days,
                baseline: _thinBaseline(days),
              ),
              withGoals: false,
            ),
          ),
      };
      expect(actual, pinned);
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
      final String plain = _snapshot(
        trajectoryTestComparison(baseline: baseline),
      );
      expect(_snapshot(calibrated(baseline, null)), plain);
      expect(
        _snapshot(
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
