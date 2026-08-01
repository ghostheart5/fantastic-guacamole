import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/archive_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/reopen_goal.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(List<GoalEntity> initial)
    : _goals = List<GoalEntity>.of(initial);

  final List<GoalEntity> _goals;
  final List<String> deletedGoalIds = <String>[];

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.of(_goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    final int index = _goals.indexWhere((GoalEntity item) => item.id == goal.id);
    if (index >= 0) {
      _goals[index] = goal;
      return;
    }
    _goals.add(goal);
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

  GoalEntity byId(String id) {
    return _goals.firstWhere((GoalEntity goal) => goal.id == id);
  }
}

void main() {
  group('Goal transition matrix contract', () {
    test('active -> completed -> archived -> active retains lifecycle timestamps',
        () async {
      final DateTime createdAt = DateTime.utc(2025, 1, 1);
      final GoalEntity seed = GoalEntity(
        id: 'g-seed',
        title: 'Lifecycle path',
        createdAt: createdAt,
      );
      final _FakeGoalRepository repository = _FakeGoalRepository(<GoalEntity>[seed]);

      final CompleteGoal completeGoal = CompleteGoal(repository);
      final ArchiveGoal archiveGoal = ArchiveGoal(repository);
      final ReopenGoal reopenGoal = ReopenGoal(repository);

      await completeGoal.call('g-seed');
      final GoalEntity completed = repository.byId('g-seed');
      expect(completed.status, GoalStatus.completed);
      expect(completed.completedAt, isNotNull);

      await archiveGoal.call('g-seed');
      final GoalEntity archived = repository.byId('g-seed');
      expect(archived.status, GoalStatus.archived);
      expect(archived.archivedAt, isNotNull);
      expect(archived.completedAt, completed.completedAt);

      await reopenGoal.call('g-seed');
      final GoalEntity reopened = repository.byId('g-seed');
      expect(reopened.status, GoalStatus.active);
      expect(reopened.completedAt, completed.completedAt);
      expect(reopened.archivedAt, archived.archivedAt);
    });

    test('archiving an active goal sets archived status directly', () async {
      final GoalEntity seed = GoalEntity(
        id: 'g-archive-active',
        title: 'Archive active',
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final _FakeGoalRepository repository = _FakeGoalRepository(<GoalEntity>[seed]);

      await ArchiveGoal(repository).call('g-archive-active');
      final GoalEntity archived = repository.byId('g-archive-active');

      expect(archived.status, GoalStatus.archived);
      expect(archived.archivedAt, isNotNull);
    });

    test('completing an archived goal reclassifies it as completed', () async {
      final GoalEntity archivedSeed = GoalEntity(
        id: 'g-archived-seed',
        title: 'Archived seed',
        createdAt: DateTime.utc(2025, 1, 1),
        status: GoalStatus.archived,
        archivedAt: DateTime.utc(2025, 1, 2),
      );
      final _FakeGoalRepository repository = _FakeGoalRepository(<GoalEntity>[
        archivedSeed,
      ]);

      await CompleteGoal(repository).call('g-archived-seed');
      final GoalEntity completed = repository.byId('g-archived-seed');

      expect(completed.status, GoalStatus.completed);
      expect(completed.completedAt, isNotNull);
      expect(completed.archivedAt, archivedSeed.archivedAt);
    });

    test('missing ids are no-op for complete/archive/reopen', () async {
      final GoalEntity seed = GoalEntity(
        id: 'g-present',
        title: 'Present goal',
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final _FakeGoalRepository repository = _FakeGoalRepository(<GoalEntity>[seed]);

      await CompleteGoal(repository).call('missing');
      await ArchiveGoal(repository).call('missing');
      await ReopenGoal(repository).call('missing');

      final GoalEntity current = repository.byId('g-present');
      expect(current.status, GoalStatus.active);
      expect(repository.deletedGoalIds, isEmpty);
    });
  });
}
