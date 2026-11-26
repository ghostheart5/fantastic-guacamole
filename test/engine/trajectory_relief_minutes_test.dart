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
