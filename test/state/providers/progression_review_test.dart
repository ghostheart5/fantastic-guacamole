import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'empty milestones remain unmeasured even with a neutral health score',
    () {
      final review = buildProgressionReview(
        execution: const ExecutionSignals(
          createdToday: 1,
          completedToday: 1,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 1,
          completed7d: 1,
          skipped7d: 0,
          delayed7d: 0,
        ),
        pressureIndex: 66,
        timelineHealth: 100,
        timelineRisk: 0,
        overdue: 0,
        milestoneHealth: 100,
        milestoneOverdue: 0,
        milestoneCount: 0,
        activeGoals: 8,
        activeTasks: 3,
      );
      expect(
        review,
        contains(
          'No milestones recorded yet; milestone health is not available',
        ),
      );
      expect(review, isNot(contains('Milestones are on-track')));
      expect(review, isNot(contains('Milestones need tighter execution')));
    },
  );
  test(
    'progress review uses real seven-day outcome keys and no advisor copy',
    () {
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
        milestoneCount: 2,
        activeGoals: 2,
        activeTasks: 4,
      );

      expect(review, contains('6 of 8 recorded outcomes were completed (75%)'));
      expect(review, contains('PROGRESS REVIEW'));
      expect(review, isNot(contains('Advisor baseline')));
      expect(review, isNot(contains('Users see next step')));
    },
  );
}
