import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteGoal', () {
    late _FakeGoalRepository repository;

    GoalEntity seedGoal() => GoalEntity(
      id: 'goal-1',
      title: 'Ship v1',
      createdAt: DateTime.utc(2026, 7, 4),
    );

    setUp(() {
      repository = _FakeGoalRepository();
    });

    test('does not delete the goal', () async {
      await repository.saveGoal(seedGoal());

      await CompleteGoal(
        repository,
      ).call('goal-1', completedAt: DateTime.utc(2026, 7, 6));

      expect(repository.getGoals(), hasLength(1));
      expect(
        repository.deletedGoalIds,
        isEmpty,
        reason: 'CompleteGoal must never call deleteGoal',
      );
    });

    test('persists completion state and timestamp', () async {
      await repository.saveGoal(seedGoal());

      await CompleteGoal(
        repository,
      ).call('goal-1', completedAt: DateTime.utc(2026, 7, 6));

      final GoalEntity stored = repository.getGoals().single;
      expect(stored.isCompleted, isTrue);
      expect(stored.completedAt, DateTime.utc(2026, 7, 6));
      expect(stored.title, 'Ship v1', reason: 'other fields are preserved');
    });

    test('is idempotent and keeps the original completion timestamp', () async {
      await repository.saveGoal(seedGoal());
      final CompleteGoal completeGoal = CompleteGoal(repository);

      await completeGoal.call('goal-1', completedAt: DateTime.utc(2026, 7, 6));
      await completeGoal.call('goal-1', completedAt: DateTime.utc(2026, 7, 9));

      expect(repository.getGoals().single.completedAt, DateTime.utc(2026, 7, 6));
    });

    test('rejects a blank id', () async {
      await expectLater(
        () => CompleteGoal(repository).call('  '),
        throwsArgumentError,
      );
      expect(repository.savedGoalIds, isEmpty);
    });

    test('throws when the goal does not exist', () async {
      await expectLater(
        () => CompleteGoal(repository).call('missing'),
        throwsStateError,
      );
    });
  });

  group('DeleteGoal remains the only destructive path', () {
    test('removes the goal', () async {
      final _FakeGoalRepository repository = _FakeGoalRepository();
      await repository.saveGoal(
        GoalEntity(
          id: 'goal-1',
          title: 'Ship v1',
          createdAt: DateTime.utc(2026, 7, 4),
        ),
      );

      await DeleteGoal(repository).call('goal-1');

      expect(repository.getGoals(), isEmpty);
      expect(repository.deletedGoalIds, <String>['goal-1']);
    });

    test('rejects a blank id before reaching the repository', () async {
      final _FakeGoalRepository repository = _FakeGoalRepository();

      await expectLater(
        () => DeleteGoal(repository).call(''),
        throwsArgumentError,
      );
      expect(repository.deletedGoalIds, isEmpty);
    });
  });

  group('GoalEntity completion state', () {
    test('survives a JSON round trip', () {
      final GoalEntity goal = GoalEntity(
        id: 'goal-1',
        title: 'Ship v1',
        createdAt: DateTime.utc(2026, 7, 4),
        description: 'the first release',
        targetDate: DateTime.utc(2026, 8, 1),
      ).markCompleted(DateTime.utc(2026, 7, 6));

      final GoalEntity restored = GoalEntity.fromJson(goal.toJson());

      expect(restored.id, goal.id);
      expect(restored.title, goal.title);
      expect(restored.description, goal.description);
      expect(restored.targetDate, goal.targetDate);
      expect(restored.colorHex, goal.colorHex);
      expect(restored.completedAt, DateTime.utc(2026, 7, 6));
      expect(restored.isCompleted, isTrue);
    });

    test('an active goal round trips as not completed', () {
      final GoalEntity goal = GoalEntity(
        id: 'goal-2',
        title: 'Active',
        createdAt: DateTime.utc(2026, 7, 4),
      );

      final GoalEntity restored = GoalEntity.fromJson(goal.toJson());

      expect(restored.isCompleted, isFalse);
      expect(restored.completedAt, isNull);
    });

    test('reopen clears the completion state', () {
      final GoalEntity goal = GoalEntity(
        id: 'goal-3',
        title: 'Reopened',
        createdAt: DateTime.utc(2026, 7, 4),
      ).markCompleted(DateTime.utc(2026, 7, 6));

      expect(goal.reopen().isCompleted, isFalse);
    });
  });
}

class _FakeGoalRepository implements IGoalRepository {
  final List<GoalEntity> _goals = <GoalEntity>[];
  final List<String> savedGoalIds = <String>[];
  final List<String> deletedGoalIds = <String>[];

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.from(_goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    savedGoalIds.add(goal.id);
    final int index = _goals.indexWhere((GoalEntity g) => g.id == goal.id);
    if (index >= 0) {
      _goals[index] = goal;
    } else {
      _goals.add(goal);
    }
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    _goals
      ..clear()
      ..addAll(goals);
  }

  @override
  Future<void> deleteGoal(String id) async {
    deletedGoalIds.add(id);
    _goals.removeWhere((GoalEntity goal) => goal.id == id);
  }
}
