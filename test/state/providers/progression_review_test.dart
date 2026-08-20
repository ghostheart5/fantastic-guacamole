import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress review uses real seven-day outcome keys and no advisor copy', () {
    const ExecutionSignals execution = ExecutionSignals(
      createdToday: 2,
      completedToday: 1,
      skippedToday: 0,
      delayedToday: 0,
      created7d: 8,
      completed7d: 6,
      skipped7d: 1,
      delayed7d: 1,
    );

    final String review = buildProgressionReview(
      execution: execution,
      pressureIndex: 42,
      timelineHealth: 82,
      timelineRisk: 18,
      overdue: 0,
      milestoneHealth: 78,
      milestoneOverdue: 0,
      activeGoals: 2,
      activeTasks: 4,
    );

    expect(review, contains('6 of 8 recorded outcomes were completed (75%)'));
    expect(review, contains('PROGRESS REVIEW'));
    expect(review, isNot(contains('Advisor baseline')));
    expect(review, isNot(contains('Users see next step')));
  });
}
