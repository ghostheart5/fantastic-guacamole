import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/create_project.dart';
import 'package:fantastic_guacamole/domain/usecases/create_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/create_subtask.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTimelineRepository implements ITimelineRepository {
  final List<TimelineEventEntity> addedEvents = <TimelineEventEntity>[];

  @override
  List<TimelineEventEntity> getEvents() => <TimelineEventEntity>[];

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    addedEvents.add(event);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}

  @override
  Future<void> removeEvent(String id) async {}
}

class _FakeGoalRepository implements IGoalRepository {
  final List<GoalEntity> savedGoals = <GoalEntity>[];
  final List<String> deletedGoalIds = <String>[];

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.of(savedGoals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    final int existingIndex = savedGoals.indexWhere(
      (GoalEntity item) => item.id == goal.id,
    );
    if (existingIndex >= 0) {
      savedGoals[existingIndex] = goal;
      return;
    }
    savedGoals.add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {
    deletedGoalIds.add(id);
  }
}

class _FakeProjectRepository implements IProjectRepository {
  final List<ProjectEntity> savedProjects = <ProjectEntity>[];

  @override
  List<ProjectEntity> getProjects() => <ProjectEntity>[];

  @override
  Future<void> saveProject(ProjectEntity project) async {
    savedProjects.add(project);
  }

  @override
  Future<void> saveProjects(List<ProjectEntity> projects) async {}

  @override
  Future<void> deleteProject(String id) async {}
}

class _FakeRoutineRepository implements IRoutineRepository {
  final List<RoutineEntity> savedRoutines = <RoutineEntity>[];

  @override
  List<RoutineEntity> getRoutines() => <RoutineEntity>[];

  @override
  Future<void> saveRoutine(RoutineEntity routine) async {
    savedRoutines.add(routine);
  }

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) async {}

  @override
  Future<void> deleteRoutine(String id) async {}
}

class _FakeSubtaskRepository implements ISubtaskRepository {
  final List<SubtaskEntity> savedSubtasks = <SubtaskEntity>[];

  @override
  List<SubtaskEntity> getSubtasks() => <SubtaskEntity>[];

  @override
  Future<void> saveSubtask(SubtaskEntity subtask) async {
    savedSubtasks.add(subtask);
  }

  @override
  Future<void> saveSubtasks(List<SubtaskEntity> subtasks) async {}

  @override
  Future<void> deleteSubtask(String id) async {}
}

void main() {
  group('use case command coverage', () {
    test('add timeline event delegates to repository', () async {
      final _FakeTimelineRepository repository = _FakeTimelineRepository();
      final AddTimelineEvent useCase = AddTimelineEvent(repository);
      final TimelineEventEntity event = TimelineEventEntity(
        id: 'e-1',
        type: TimelineEventType.task,
        title: 'Task updated',
        detail: 'Moved to focus lane',
        timestamp: DateTime.utc(2025, 1, 10),
      );

      await useCase.call(event);

      expect(repository.addedEvents, hasLength(1));
      expect(repository.addedEvents.single.id, 'e-1');
      expect(repository.addedEvents.single.title, 'Task updated');
    });

    test('goal use cases delegate save and delete operations', () async {
      final _FakeGoalRepository repository = _FakeGoalRepository();
      final CreateGoal createGoal = CreateGoal(repository);
      final CompleteGoal completeGoal = CompleteGoal(repository);
      final DeleteGoal deleteGoal = DeleteGoal(repository);
      final GoalEntity goal = GoalEntity(
        id: 'g-1',
        title: 'Ship coverage gate',
        createdAt: DateTime.utc(2025, 2, 1),
      );

      await createGoal.call(goal);
      await completeGoal.call('g-1');
      await deleteGoal.call('g-2');

      expect(repository.savedGoals, hasLength(1));
      final GoalEntity persistedGoal = repository.savedGoals.single;
      expect(persistedGoal.id, 'g-1');
      expect(persistedGoal.status, GoalStatus.completed);
      expect(persistedGoal.completedAt, isNotNull);
      expect(repository.deletedGoalIds, <String>['g-2']);
    });

    test('project, routine, and subtask use cases delegate save', () async {
      final _FakeProjectRepository projectRepository = _FakeProjectRepository();
      final _FakeRoutineRepository routineRepository = _FakeRoutineRepository();
      final _FakeSubtaskRepository subtaskRepository = _FakeSubtaskRepository();

      final CreateProject createProject = CreateProject(projectRepository);
      final CreateRoutine createRoutine = CreateRoutine(routineRepository);
      final CreateSubtask createSubtask = CreateSubtask(subtaskRepository);

      final ProjectEntity project = ProjectEntity(
        id: 'p-1',
        name: 'Planner v1',
        createdAt: DateTime.utc(2025, 3, 3),
      );
      final RoutineEntity routine = RoutineEntity(
        id: 'r-1',
        name: 'Morning setup',
        createdAt: DateTime.utc(2025, 3, 4),
      );
      final SubtaskEntity subtask = SubtaskEntity(
        id: 's-1',
        parentTaskId: 't-100',
        title: 'Write acceptance tests',
        createdAt: DateTime.utc(2025, 3, 5),
      );

      await createProject.call(project);
      await createRoutine.call(routine);
      await createSubtask.call(subtask);

      expect(projectRepository.savedProjects.single.id, 'p-1');
      expect(routineRepository.savedRoutines.single.id, 'r-1');
      expect(subtaskRepository.savedSubtasks.single.id, 's-1');
    });
  });
}
