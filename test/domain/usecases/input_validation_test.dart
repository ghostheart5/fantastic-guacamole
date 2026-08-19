import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_project.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_subtask.dart';
import 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/save_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/save_projects.dart';
import 'package:fantastic_guacamole/domain/usecases/save_routines.dart';
import 'package:fantastic_guacamole/domain/usecases/save_subtasks.dart';
import 'package:fantastic_guacamole/domain/usecases/save_timeline_events.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _blankIds = <String>['', ' ', '   ', '\t', '\n'];

void main() {
  group('InputGuard.id', () {
    test('rejects every blank form', () {
      for (final String blank in _blankIds) {
        expect(
          () => InputGuard.id(blank, 'id'),
          throwsArgumentError,
          reason: 'blank id ${blank.codeUnits} must be rejected',
        );
      }
    });

    test('passes a real id through unchanged', () {
      expect(InputGuard.id('goal-1', 'id'), 'goal-1');
    });
  });

  group('InputGuard.batch', () {
    test('rejects an empty list unless clearing is explicit', () {
      expect(
        () => InputGuard.batch(<String>[], 'items', allowClear: false),
        throwsArgumentError,
      );
    });

    test('allows an explicitly intended clear', () {
      expect(InputGuard.batch(<String>[], 'items', allowClear: true), isEmpty);
    });

    test('always allows a non-empty list', () {
      expect(
        InputGuard.batch(<String>['a'], 'items', allowClear: false),
        <String>['a'],
      );
    });
  });

  group('destructive use cases reject blank ids', () {
    test('DeleteProject', () async {
      final _FakeProjectRepository repository = _FakeProjectRepository();
      for (final String blank in _blankIds) {
        await expectLater(
          () => DeleteProject(repository).call(blank),
          throwsArgumentError,
        );
      }
      expect(repository.deletedIds, isEmpty);
    });

    test('DeleteRoutine', () async {
      final _FakeRoutineRepository repository = _FakeRoutineRepository();
      await expectLater(
        () => DeleteRoutine(repository).call(' '),
        throwsArgumentError,
      );
      expect(repository.deletedIds, isEmpty);
    });

    test('DeleteSubtask', () async {
      final _FakeSubtaskRepository repository = _FakeSubtaskRepository();
      await expectLater(
        () => DeleteSubtask(repository).call(''),
        throwsArgumentError,
      );
      expect(repository.deletedIds, isEmpty);
    });

    test('DeleteMemory', () async {
      final _FakeMemoryRepository repository = _FakeMemoryRepository();
      await expectLater(
        () => DeleteMemory(repository).call('   '),
        throwsArgumentError,
      );
      expect(repository.deletedIds, isEmpty);
    });

    test('RemoveTimelineEvent', () async {
      final _FakeTimelineRepository repository = _FakeTimelineRepository();
      await expectLater(
        () => RemoveTimelineEvent(repository).call(' '),
        throwsArgumentError,
      );
      expect(repository.removedIds, isEmpty);
    });
  });

  group('bulk saves refuse to wipe a collection by accident', () {
    test('SaveGoals', () async {
      final _FakeGoalRepository repository = _FakeGoalRepository();
      repository.stored.add(
        GoalEntity(
          id: 'goal-1',
          title: 'Ship v1',
          createdAt: DateTime.utc(2026, 7, 4),
        ),
      );

      await expectLater(
        () => SaveGoals(repository).call(<GoalEntity>[]),
        throwsArgumentError,
      );
      expect(
        repository.stored,
        hasLength(1),
        reason: 'existing goals must survive an accidental empty save',
      );

      await SaveGoals(repository).call(<GoalEntity>[], allowClear: true);
      expect(repository.stored, isEmpty, reason: 'explicit clear is allowed');
    });

    test('SaveProjects', () async {
      final _FakeProjectRepository repository = _FakeProjectRepository();
      await expectLater(
        () => SaveProjects(repository).call(<ProjectEntity>[]),
        throwsArgumentError,
      );
      expect(repository.savedBatches, isEmpty);
    });

    test('SaveRoutines', () async {
      final _FakeRoutineRepository repository = _FakeRoutineRepository();
      await expectLater(
        () => SaveRoutines(repository).call(<HabitEntity>[]),
        throwsArgumentError,
      );
      expect(repository.savedBatches, isEmpty);
    });

    test('SaveSubtasks', () async {
      final _FakeSubtaskRepository repository = _FakeSubtaskRepository();
      await expectLater(
        () => SaveSubtasks(repository).call(<SubtaskEntity>[]),
        throwsArgumentError,
      );
      expect(repository.savedBatches, isEmpty);
    });

    test('SaveMemories', () async {
      final _FakeMemoryRepository repository = _FakeMemoryRepository();
      await expectLater(
        () => SaveMemories(repository).call(<MemoryEntity>[]),
        throwsArgumentError,
      );
      expect(repository.savedBatches, isEmpty);
    });

    test('SaveTimelineEvents', () async {
      final _FakeTimelineRepository repository = _FakeTimelineRepository();
      await expectLater(
        () => SaveTimelineEvents(repository).call(<TimelineEventEntity>[]),
        throwsArgumentError,
      );
      expect(repository.savedBatches, isEmpty);
    });
  });
}

class _FakeGoalRepository implements IGoalRepository {
  final List<GoalEntity> stored = <GoalEntity>[];

  @override
  List<GoalEntity> getGoals() => stored;

  @override
  Future<void> saveGoal(GoalEntity goal) async => stored.add(goal);

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    stored
      ..clear()
      ..addAll(goals);
  }

  @override
  Future<void> deleteGoal(String id) async =>
      stored.removeWhere((GoalEntity g) => g.id == id);
}

class _FakeProjectRepository implements IProjectRepository {
  final List<String> deletedIds = <String>[];
  final List<List<ProjectEntity>> savedBatches = <List<ProjectEntity>>[];

  @override
  List<ProjectEntity> getProjects() => const <ProjectEntity>[];

  @override
  Future<void> saveProject(ProjectEntity project) async {}

  @override
  Future<void> saveProjects(List<ProjectEntity> projects) async =>
      savedBatches.add(projects);

  @override
  Future<void> deleteProject(String id) async => deletedIds.add(id);
}

class _FakeRoutineRepository implements IRoutineRepository {
  final List<String> deletedIds = <String>[];
  final List<List<HabitEntity>> savedBatches = <List<HabitEntity>>[];

  @override
  List<HabitEntity> getRoutines() => const <HabitEntity>[];

  @override
  Future<void> saveRoutine(HabitEntity routine) async {}

  @override
  Future<void> saveRoutines(List<HabitEntity> routines) async =>
      savedBatches.add(routines);

  @override
  Future<void> deleteRoutine(String id) async => deletedIds.add(id);
}

class _FakeSubtaskRepository implements ISubtaskRepository {
  final List<String> deletedIds = <String>[];
  final List<List<SubtaskEntity>> savedBatches = <List<SubtaskEntity>>[];

  @override
  List<SubtaskEntity> getSubtasks() => const <SubtaskEntity>[];

  @override
  Future<void> saveSubtask(SubtaskEntity subtask) async {}

  @override
  Future<void> saveSubtasks(List<SubtaskEntity> subtasks) async =>
      savedBatches.add(subtasks);

  @override
  Future<void> deleteSubtask(String id) async => deletedIds.add(id);
}

class _FakeMemoryRepository implements IMemoryRepository {
  final List<String> deletedIds = <String>[];
  final List<List<MemoryEntity>> savedBatches = <List<MemoryEntity>>[];

  @override
  List<MemoryEntity> getMemories() => const <MemoryEntity>[];

  @override
  Future<void> saveMemory(MemoryEntity memory) async {}

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async =>
      savedBatches.add(memories);

  @override
  Future<void> deleteMemory(String id) async => deletedIds.add(id);
}

class _FakeTimelineRepository implements ITimelineRepository {
  final List<String> removedIds = <String>[];
  final List<List<TimelineEventEntity>> savedBatches =
      <List<TimelineEventEntity>>[];

  @override
  List<TimelineEventEntity> getEvents() => const <TimelineEventEntity>[];

  @override
  Future<void> addEvent(TimelineEventEntity event) async {}

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async =>
      savedBatches.add(events);

  @override
  Future<void> removeEvent(String id) async => removedIds.add(id);
}
