import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/phase10/deterministic_generators.dart';

class _TaskRepository implements ITaskRepository {
  _TaskRepository(TaskEntity task)
    : _tasks = <String, TaskEntity>{task.id: task};

  final Map<String, TaskEntity> _tasks;
  int saves = 0;

  @override
  Future<void> deleteTask(String id) async => _tasks.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => _tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    saves++;
    _tasks[task.id] = task;
  }
}

class _ProgressionRepository implements IProgressionRepository {
  ProgressionEntity value = const ProgressionEntity();
  int saves = 0;

  @override
  Future<ProgressionEntity?> getProgression() async => value;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    saves++;
    value = progression;
  }
}

void main() {
  test('completing twice cannot grant progress twice', () async {
    for (final int seed in phase10Seeds) {
      final DeterministicGenerator g = DeterministicGenerator(seed);
      final TaskEntity task = TaskEntity(
        id: g.id('task'),
        title: g.unicodeText(length: g.between(1, 120)),
        createdAt: g.utcInstant(),
      );
      final _TaskRepository tasks = _TaskRepository(task);
      final _ProgressionRepository progression = _ProgressionRepository();
      final CompleteTask complete = CompleteTask(
        tasks,
        progressionRepo: progression,
      );
      await complete.call(task.id);
      await expectLater(complete.call(task.id), throwsStateError);
      expect(progression.value.xp, 10, reason: 'seed=$seed');
      expect(progression.saves, 1, reason: 'seed=$seed');
      expect(tasks.saves, 1, reason: 'seed=$seed');
    }
  });

  test(
    'fixed seeds preserve task, goal, habit, routine, note and Timeline data',
    () {
      for (final int seed in phase10Seeds) {
        final DeterministicGenerator g = DeterministicGenerator(seed);
        final DateTime created = g.utcInstant();
        final String title = g.unicodeText(length: g.between(1, 4096));
        final TaskEntity task = TaskEntity(
          id: g.id('task'),
          title: title,
          createdAt: created,
          scheduledFor: created.add(Duration(hours: g.between(0, 240))),
          priority: g.between(1, 5),
          difficulty: g.between(1, 5),
          energyRequired: g.between(1, 5),
          recurrenceRule: RecurrenceRule.values[g.between(0, 2)],
        );
        final TaskEntity taskRoundTrip = TaskEntityMapper.fromJson(
          TaskEntityMapper.toJson(task),
        );
        final String reason = 'seed=$seed';
        expect(taskRoundTrip.id, task.id, reason: reason);
        expect(taskRoundTrip.title, task.title, reason: reason);
        expect(taskRoundTrip.scheduledFor, task.scheduledFor, reason: reason);
        expect(taskRoundTrip.priority, task.priority, reason: reason);
        expect(taskRoundTrip.difficulty, task.difficulty, reason: reason);
        expect(
          taskRoundTrip.energyRequired,
          task.energyRequired,
          reason: reason,
        );
        expect(
          taskRoundTrip.recurrenceRule,
          task.recurrenceRule,
          reason: reason,
        );

        final GoalEntity goal = GoalEntity(
          id: g.id('goal'),
          title: title,
          createdAt: created,
          targetDate: created.add(const Duration(days: 30)),
        );
        final GoalEntity completedGoal = goal.markCompleted(created);
        final GoalEntity archivedGoal = completedGoal.archive(
          created.add(const Duration(days: 1)),
        );
        expect(GoalEntity.fromJson(goal.toJson()).title, title, reason: reason);
        expect(completedGoal.status, GoalStatus.completed, reason: reason);
        expect(archivedGoal.status, GoalStatus.archived, reason: reason);
        expect(archivedGoal.id, goal.id, reason: reason);

        final HabitEntity habit = HabitEntity(
          id: g.id('habit'),
          title: title,
          createdAt: created,
          targetCount: g.between(1, 365),
        );
        expect(
          HabitEntity.fromJson(habit.toJson()).title,
          habit.title,
          reason: reason,
        );
        final RoutineEntity routine = RoutineEntity(
          id: g.id('routine'),
          name: title,
          createdAt: created,
          stepTaskIds: <String>[task.id],
          targetCount: g.between(1, 365),
        );
        expect(RoutineEntity.fromJson(routine.toJson()).stepTaskIds, <String>[
          task.id,
        ], reason: reason);
        final NoteEntity note = NoteEntity(
          id: g.id('note'),
          title: title,
          body: g.unicodeText(length: g.between(0, 4096)),
          createdAt: created,
        );
        final NoteEntity noteRoundTrip = NoteEntity.fromJson(note.toJson());
        expect(noteRoundTrip.title, title, reason: reason);
        expect(noteRoundTrip.body, note.body, reason: reason);

        final List<TimelineEventEntity> ordered =
            List<TimelineEventEntity>.generate(
              12,
              (int index) => TimelineEventEntity(
                id: 'timeline-$seed-$index',
                type: TimelineEventType.task,
                title: title,
                detail: 'detail-$index',
                timestamp: created.add(Duration(minutes: index)),
              ),
            )..sort(
              (TimelineEventEntity a, TimelineEventEntity b) =>
                  a.timestamp.compareTo(b.timestamp),
            );
        for (int index = 1; index < ordered.length; index++) {
          expect(
            ordered[index - 1].timestamp.compareTo(ordered[index].timestamp),
            lessThanOrEqualTo(0),
          );
        }
        expect(
          TimelineEventEntity.fromJson(ordered.last.toJson()).id,
          ordered.last.id,
          reason: reason,
        );
      }
    },
  );

  test(
    'malformed task payloads fail closed instead of becoming a lifecycle item',
    () {
      expect(
        () => TaskEntityMapper.fromJson(<String, dynamic>{
          'id': 'task-corrupt',
          'title': 'bad',
          'createdAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    },
  );
}
