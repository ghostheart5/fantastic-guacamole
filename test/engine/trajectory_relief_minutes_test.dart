import 'dart:convert';

import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/future_outcomes_harness.dart';
import '../helpers/trajectory_test_fixture.dart';

/// The minutes an option takes out of its range, as the engine counts them
/// for the workload, are on the outcome; receipts do not carry them.
void main() {
  int relief(TrajectoryComparison c, String id) =>
      c.outcomes.firstWhere((o) => o.intervention.id == id).reliefMinutes;

  test('finishing or removing a task in the range frees its minutes', () {
    for (final int days in const <int>[7, 90]) {
      final TrajectoryComparison c = futureOutcomesComparison(days: days);
      expect(relief(c, 'complete-task-a'), 60, reason: '$days');
      expect(relief(c, 'remove-task-d'), 30, reason: '$days');
      expect(relief(c, 'maintain'), 0, reason: '$days');
      expect(relief(c, 'planner'), 0, reason: '$days');
      expect(relief(c, 'delay-task-a'), 0, reason: '$days');
    }
  });

  test('the reduce option pace change reads the selected range workload, '
      'not the next 7 days', () {
    // Heavy next 7 days (80), light over 90 days.
    final TrajectoryBaseline baseline = trajectoryTestBaseline(
      pressure: 80,
      horizonDays: 90,
      tasks: <TrajectoryTaskNode>[
        TrajectoryTaskNode(
          id: 'soon',
          title: 'Due soon',
          priority: 3,
          estimatedMinutes: 600,
          dueAt: trajectoryFixtureNow.add(const Duration(days: 2)),
        ),
        const TrajectoryTaskNode(
          id: 'spare',
          title: 'Spare',
          priority: 1,
          estimatedMinutes: 30,
        ),
      ],
      dailyFreeMinutes: 120,
    );
    TrajectoryScenarioOutcome reduceOver(int days) =>
        const FutureConsequenceEngine().project(
          baseline: baseline,
          generatedAt: trajectoryFixtureNow,
          intervention: TrajectoryIntervention(
            id: 'remove-spare',
            type: TrajectoryInterventionType.reduceScope,
            title: 'Reduce lower-priority scope',
            horizon: Duration(days: days),
            description: 'Remove Spare.',
            subjectId: 'spare',
          ),
        );
    // 630 minutes over 7 days of 120: 75% (heavy) -> the larger pace gain.
    expect(reduceOver(7).projectedMomentum, baseline.momentum + 4);
    // 630 minutes over 90 days of 120: 6% (light) -> the small one.
    expect(reduceOver(90).projectedMomentum, baseline.momentum + 1);
  });

  test('a task outside the range frees nothing', () {
    final TrajectoryBaseline baseline = futureOutcomesBaseline();
    final TrajectoryComparison c = const FutureConsequenceEngine().compare(
      baseline: baseline,
      generatedAt: trajectoryFixtureNow,
      interventions: <TrajectoryIntervention>[
        for (final int days in const <int>[7, 30])
          TrajectoryIntervention(
            id: 'complete-task-b-$days',
            type: TrajectoryInterventionType.completeTask,
            title: 'Complete Prepare the review',
            horizon: Duration(days: days),
            description: 'Finish the review.',
            subjectId: 'task-b',
          ),
      ],
    );
    // Due in 20 days: outside 7 days, inside 30.
    expect(relief(c, 'complete-task-b-7'), 0);
    expect(relief(c, 'complete-task-b-30'), 120);
  });

  test('the receipt JSON has no relief field', () {
    final TrajectoryComparison c = futureOutcomesComparison();
    final TrajectoryScenarioOutcome outcome = c.outcomes.firstWhere(
      (o) => o.intervention.id == 'complete-task-a',
    );
    expect(outcome.reliefMinutes, 60);
    final TrajectoryForecastReceipt receipt =
        TrajectoryForecastReceipt.fromScenario(
          baseline: c.baseline,
          outcome: outcome,
          selectedAt: trajectoryFixtureNow,
        );
    final String json = jsonEncode(receipt.toJson());
    expect(json, isNot(contains('relief')));
    expect(json, isNot(contains('"60"')));
  });
}
