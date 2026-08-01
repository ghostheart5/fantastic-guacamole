import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_active_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_archived_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_completed_goals_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(this._goals);

  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.of(_goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

void main() {
  group('Goal status visibility contract', () {
    test('active/completed/archived views are driven by status only', () {
      final DateTime createdAt = DateTime.utc(2025, 1, 1);

      final GoalEntity activeWithCompletedAt = GoalEntity(
        id: 'g-active-weird',
        title: 'Active with historical completion timestamp',
        createdAt: createdAt,
        status: GoalStatus.active,
        completedAt: DateTime.utc(2025, 1, 2),
      );

      final GoalEntity completedWithoutCompletedAt = GoalEntity(
        id: 'g-completed',
        title: 'Completed by status only',
        createdAt: createdAt,
        status: GoalStatus.completed,
      );

      final GoalEntity archivedWithoutArchivedAt = GoalEntity(
        id: 'g-archived',
        title: 'Archived by status only',
        createdAt: createdAt,
        status: GoalStatus.archived,
      );

      final _FakeGoalRepository repository = _FakeGoalRepository(<GoalEntity>[
        activeWithCompletedAt,
        completedWithoutCompletedAt,
        archivedWithoutArchivedAt,
      ]);

      final List<GoalEntity> active = ViewActiveGoalsUsecase(repository).call();
      final List<GoalEntity> completed =
          ViewCompletedGoalsUsecase(repository).call();
      final List<GoalEntity> archived = ViewArchivedGoalsUsecase(repository).call();

      expect(active.map((GoalEntity g) => g.id), <String>['g-active-weird']);
      expect(completed.map((GoalEntity g) => g.id), <String>['g-completed']);
      expect(archived.map((GoalEntity g) => g.id), <String>['g-archived']);
    });
  });
}
