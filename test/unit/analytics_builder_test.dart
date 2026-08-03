import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/view_goal_trends_usecase.dart';
import 'package:fantastic_guacamole/system/analytics/global_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Analytics Builder', () {
    test('event processing handles sparse and mixed metric rows safely', () {
      final GlobalMetrics metrics = GlobalMetrics.fromRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'tasks_created': 5,
          'tasks_completed': 4,
          'momentum_peak': 6.0,
        },
        <String, dynamic>{
          'tasks_created': 0,
          'tasks_completed': 3,
          'momentum_peak': 2.0,
        },
        <String, dynamic>{
          'tasks_created': 10,
          'tasks_completed': 5,
        },
      ]);

      expect(metrics.avgTaskCompletionRate, closeTo((0.8 + 0.0 + 0.5) / 3, 1e-9));
      expect(metrics.avgMomentumPeak, closeTo((6.0 + 2.0 + 0.0) / 3, 1e-9));
    });

    test('KPI calculations return expected averages', () {
      final GlobalMetrics metrics = GlobalMetrics.fromRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'tasks_created': 10,
          'tasks_completed': 8,
          'momentum_peak': 4.5,
        },
        <String, dynamic>{
          'tasks_created': 4,
          'tasks_completed': 1,
          'momentum_peak': 2.0,
        },
      ]);

      expect(metrics.avgTaskCompletionRate, 0.525);
      expect(metrics.avgMomentumPeak, 3.25);
    });

    test('trend generation buckets goals into 7, 30, and 365 day windows', () {
      final DateTime now = DateTime.now();
      final ViewGoalTrendsUsecase usecase = ViewGoalTrendsUsecase(
        _FakeGoalRepository(<GoalEntity>[
          GoalEntity(id: 'g1', title: 'Recent', createdAt: now.subtract(const Duration(days: 2))),
          GoalEntity(id: 'g2', title: 'WeekEdge', createdAt: now.subtract(const Duration(days: 7))),
          GoalEntity(id: 'g3', title: 'Month', createdAt: now.subtract(const Duration(days: 20))),
          GoalEntity(id: 'g4', title: 'Year', createdAt: now.subtract(const Duration(days: 200))),
          GoalEntity(id: 'g5', title: 'Old', createdAt: now.subtract(const Duration(days: 500))),
        ]),
      );

      final GoalTrendsResult result = usecase.call();

      expect(result.createdLast7Days, 2);
      expect(result.createdLast30Days, 3);
      expect(result.createdLast365Days, 4);
    });
  });
}

class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(this._goals);

  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> getGoals() => _goals;

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
}
