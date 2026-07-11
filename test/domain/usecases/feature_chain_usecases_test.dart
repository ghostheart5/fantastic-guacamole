import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_flowmap_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/cancel_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_flowmap_node.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/get_flowmap_nodes.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/save_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/save_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/schedule_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/update_flowmap_node.dart';
import 'package:fantastic_guacamole/domain/usecases/update_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goal usecases', () {
    late _FakeGoalRepository repository;

    setUp(() {
      repository = _FakeGoalRepository();
    });

    test(
      'create/get/update/delete/complete goal use the repository contract',
      () async {
        final GoalEntity goal = GoalEntity(
          id: 'goal-1',
          title: 'Ship v1',
          createdAt: DateTime.utc(2026, 7, 4),
        );

        await CreateGoal(repository).call(goal);
        expect(GetGoals(repository).call(), hasLength(1));
        expect(repository.savedGoalIds, <String>['goal-1']);

        final GoalEntity updated = goal.copyWith(title: 'Ship v1.1');
        await UpdateGoal(repository).call(updated);
        expect(GetGoals(repository).call().single.title, 'Ship v1.1');

        await DeleteGoal(repository).call(goal.id);
        expect(GetGoals(repository).call(), isEmpty);

        await CreateGoal(repository).call(goal);
        await CompleteGoal(repository).call(goal.id);
        expect(GetGoals(repository).call(), isEmpty);
        expect(
          repository.deletedGoalIds,
          containsAll(<String>['goal-1', 'goal-1']),
        );

        await SaveGoals(repository).call(<GoalEntity>[goal, updated]);
        expect(
          GetGoals(repository).call().map((GoalEntity item) => item.id),
          <String>['goal-1', 'goal-1'],
        );
      },
    );
  });

  group('memory usecases', () {
    late _FakeMemoryRepository repository;

    setUp(() {
      repository = _FakeMemoryRepository();
    });

    test('get/save/delete memory use the repository contract', () async {
      final MemoryEntity memory = MemoryEntity(
        id: 'memory-1',
        text: 'Finished deep work block',
        date: DateTime.utc(2026, 7, 4),
      );

      expect(GetMemories(repository).call(), isEmpty);

      await SaveMemory(repository).call(memory);
      expect(
        GetMemories(repository).call().single.text,
        'Finished deep work block',
      );

      await SaveMemories(repository).call(<MemoryEntity>[
        memory,
        MemoryEntity(
          id: 'memory-2',
          text: 'Second note',
          date: DateTime.utc(2026, 7, 5),
        ),
      ]);
      expect(GetMemories(repository).call(), hasLength(2));

      await DeleteMemory(repository).call(memory.id);
      expect(
        GetMemories(repository).call().map((MemoryEntity item) => item.id),
        <String>['memory-2'],
      );
    });
  });

  group('timeline usecases', () {
    late _FakeTimelineRepository repository;

    setUp(() {
      repository = _FakeTimelineRepository();
    });

    test('get/add/remove timeline event use the repository contract', () async {
      final TimelineEventEntity event = TimelineEventEntity(
        id: 'timeline-1',
        type: TimelineEventType.goalComplete,
        title: 'Goal completed',
        detail: 'Ship v1',
        timestamp: DateTime.utc(2026, 7, 4),
      );

      expect(GetTimelineEvents(repository).call(), isEmpty);

      await AddTimelineEvent(repository).call(event);
      expect(GetTimelineEvents(repository).call().single.id, 'timeline-1');

      await SaveTimelineEvents(repository).call(<TimelineEventEntity>[
        event,
        TimelineEventEntity(
          id: 'timeline-2',
          type: TimelineEventType.reflection,
          title: 'Memory added',
          detail: 'Logged a win',
          timestamp: DateTime.utc(2026, 7, 5),
        ),
      ]);
      expect(GetTimelineEvents(repository).call(), hasLength(2));

      await RemoveTimelineEvent(repository).call(event.id);
      expect(
        GetTimelineEvents(
          repository,
        ).call().map((TimelineEventEntity item) => item.id),
        <String>['timeline-2'],
      );
    });
  });

  group('flowmap usecases', () {
    late _FakeFlowmapRepository repository;

    setUp(() {
      repository = _FakeFlowmapRepository();
    });

    test(
      'get/update/delete flowmap node use the repository contract',
      () async {
        final FlowmapNode node = FlowmapNode(
          id: 'node-1',
          title: 'Decision graph',
          tags: const <String>['planning'],
          createdAt: DateTime.utc(2026, 7, 4),
        );

        expect(await GetFlowmap(repository).call(), isEmpty);

        await UpdateFlowmapNode(repository).call(node);
        expect(
          (await GetFlowmap(repository).call()).single.title,
          'Decision graph',
        );

        await DeleteFlowmapNode(repository).call(node.id);
        expect(await GetFlowmap(repository).call(), isEmpty);
      },
    );
  });

  group('task and si usecases', () {
    late _FakeTaskRepository taskRepository;
    late _FakeSiRepository siRepository;
    late _FakeProgressionRepository progressionRepository;

    setUp(() {
      taskRepository = _FakeTaskRepository();
      siRepository = _FakeSiRepository();
      progressionRepository = _FakeProgressionRepository();
    });

    test(
      'generate SI decision selects highest priority task and create task can simplify priority',
      () async {
        await taskRepository.saveTask(
          TaskEntity(
            id: 'low',
            title: 'Low',
            createdAt: DateTime.utc(2026, 7, 4),
            priority: 2,
          ),
        );
        await taskRepository.saveTask(
          TaskEntity(
            id: 'high',
            title: 'High',
            createdAt: DateTime.utc(2026, 7, 4),
            priority: 5,
          ),
        );
        siRepository.state = SiStateEntity(
          energy: 0.8,
          focus: 0.8,
          fatigue: 0.2,
        );

        final SiDecisionEntity decision = await GenerateSiDecision(
          taskRepository,
          siRepository,
        ).call();

        expect(decision.selectedTaskId, 'high');
        expect(decision.orderedTaskIds, <String>['high', 'low']);
        expect(decision.action, 'Focus on: High');

        await CreateTask(
          taskRepository,
          generateSiDecision: _StubGenerateSiDecision(
            const SiDecisionEntity(
              rationale: 'Simplify this task.',
              shouldSimplify: true,
            ),
          ),
        ).call(
          TaskEntity(
            id: 'new',
            title: 'Deep Work',
            createdAt: DateTime.utc(2026, 7, 5),
            priority: 4,
          ),
        );

        final TaskEntity? created = await taskRepository.getTaskById('new');
        expect(created?.priority, 1);
        expect(
          (await GetTasks(
            taskRepository,
          ).call()).map((TaskEntity item) => item.id),
          contains('new'),
        );
      },
    );

    test('generate SI decision handles break and empty-task paths', () async {
      siRepository.state = SiStateEntity(energy: 0.2, focus: 0.6, fatigue: 0.9);

      final SiDecisionEntity breakDecision = await GenerateSiDecision(
        taskRepository,
        siRepository,
      ).call();
      expect(breakDecision.shouldTakeBreak, isTrue);

      siRepository.state = SiStateEntity(energy: 0.9, focus: 0.8, fatigue: 0.1);
      final SiDecisionEntity emptyDecision = await GenerateSiDecision(
        taskRepository,
        siRepository,
      ).call();
      expect(emptyDecision.rationale, 'No tasks available.');
    });

    test(
      'complete task marks recurring tasks complete, spawns next task, and updates progression and SI',
      () async {
        siRepository.state = SiStateEntity(
          energy: 0.5,
          focus: 0.5,
          fatigue: 0.5,
          confidence: 0.4,
        );
        progressionRepository.progression = const ProgressionEntity(
          xp: 5,
          level: 1,
          streak: 0,
        );
        await taskRepository.saveTask(
          TaskEntity(
            id: 'repeat',
            title: 'Daily check-in',
            createdAt: DateTime.utc(2026, 7, 5),
            recurrenceRule: RecurrenceRule.daily,
          ),
        );

        await CompleteTask(
          taskRepository,
          siRepo: siRepository,
          progressionRepo: progressionRepository,
        ).call('repeat');

        final TaskEntity? completed = await taskRepository.getTaskById(
          'repeat',
        );
        final List<TaskEntity> tasks = await taskRepository.getAllTasks();

        expect(completed?.isCompleted, isTrue);
        expect(completed?.completedAt, isNotNull);
        expect(tasks, hasLength(2));
        expect(
          tasks
              .where((TaskEntity item) => item.id != 'repeat')
              .single
              .isCompleted,
          isFalse,
        );
        expect(progressionRepository.progression?.xp, 15);
        expect(
          siRepository.savedStates.single.confidence,
          closeTo(0.45, 0.0001),
        );
      },
    );

    test('create and complete task validate failure paths', () async {
      await expectLater(
        () => CreateTask(taskRepository).call(
          TaskEntity(
            id: 'bad',
            title: '   ',
            createdAt: DateTime.utc(2026, 7, 5),
          ),
        ),
        throwsException,
      );

      await expectLater(
        () => CompleteTask(taskRepository).call('missing'),
        throwsA(isA<StateError>()),
      );

      await taskRepository.saveTask(
        TaskEntity(
          id: 'done',
          title: 'Done',
          createdAt: DateTime.utc(2026, 7, 5),
          isCompleted: true,
        ),
      );
      await expectLater(
        () => CompleteTask(taskRepository).call('done'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('notification usecases', () {
    late _FakeNotificationRepository repository;

    setUp(() {
      repository = _FakeNotificationRepository();
    });

    test(
      'schedule notification adapts SI message and delegates to repository',
      () async {
        final NotificationEntity notification = NotificationEntity(
          id: 'notif-1',
          title: 'Nudge',
          message: 'Original',
          scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
        );

        await ScheduleNotification(
          repository,
          generateSiDecision: _StubGenerateSiDecision(
            const SiDecisionEntity(
              rationale: 'Use adaptive message.',
              action: 'Take the next focused step.',
            ),
          ),
        ).call(notification);

        expect(
          repository.scheduled.single.message,
          'Take the next focused step.',
        );
      },
    );

    test(
      'schedule notification rejects disabled or past notifications',
      () async {
        await expectLater(
          () => ScheduleNotification(repository).call(
            NotificationEntity(
              id: 'notif-2',
              title: 'Disabled',
              message: 'Nope',
              scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
              isEnabled: false,
            ),
          ),
          throwsException,
        );

        await expectLater(
          () => ScheduleNotification(repository).call(
            NotificationEntity(
              id: 'notif-3',
              title: 'Past',
              message: 'Too late',
              scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          ),
          throwsException,
        );
      },
    );

    test('cancel notification delegates to repository contract', () async {
      await CancelNotification(repository).call('notif-4');

      expect(repository.cancelledIds, <String>['notif-4']);
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
    final int index = _goals.indexWhere(
      (GoalEntity item) => item.id == goal.id,
    );
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

class _FakeMemoryRepository implements IMemoryRepository {
  final List<MemoryEntity> _memories = <MemoryEntity>[];

  @override
  List<MemoryEntity> getMemories() => List<MemoryEntity>.from(_memories);

  @override
  Future<void> saveMemory(MemoryEntity memory) async {
    final int index = _memories.indexWhere(
      (MemoryEntity item) => item.id == memory.id,
    );
    if (index >= 0) {
      _memories[index] = memory;
    } else {
      _memories.add(memory);
    }
  }

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {
    _memories
      ..clear()
      ..addAll(memories);
  }

  @override
  Future<void> deleteMemory(String id) async {
    _memories.removeWhere((MemoryEntity memory) => memory.id == id);
  }
}

class _FakeTimelineRepository implements ITimelineRepository {
  final List<TimelineEventEntity> _events = <TimelineEventEntity>[];

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.from(_events);

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    _events.insert(0, event);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {
    _events
      ..clear()
      ..addAll(events);
  }

  @override
  Future<void> removeEvent(String id) async {
    _events.removeWhere((TimelineEventEntity event) => event.id == id);
  }
}

class _FakeFlowmapRepository implements IFlowmapRepository {
  final List<FlowmapNode> _nodes = <FlowmapNode>[];

  @override
  Future<List<FlowmapNode>> getNodes() async => List<FlowmapNode>.from(_nodes);

  @override
  Future<void> saveNodes(List<FlowmapNode> nodes) async {
    _nodes
      ..clear()
      ..addAll(nodes);
  }

  @override
  Future<void> saveNode(FlowmapNode node) async {
    final int index = _nodes.indexWhere(
      (FlowmapNode item) => item.id == node.id,
    );
    if (index >= 0) {
      _nodes[index] = node;
    } else {
      _nodes.add(node);
    }
  }

  @override
  Future<void> deleteNode(String id) async {
    _nodes.removeWhere((FlowmapNode node) => node.id == id);
  }
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}

class _FakeSiRepository implements ISiRepository {
  SiStateEntity? state;
  final List<SiStateEntity> savedStates = <SiStateEntity>[];

  @override
  Future<SiStateEntity?> getCurrentState() async => state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    this.state = state;
    savedStates.add(state);
  }
}

class _FakeProgressionRepository implements IProgressionRepository {
  ProgressionEntity? progression;

  @override
  Future<ProgressionEntity?> getProgression() async => progression;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    this.progression = progression;
  }
}

class _FakeNotificationRepository implements INotificationRepository {
  final List<NotificationEntity> scheduled = <NotificationEntity>[];
  final List<String> cancelledIds = <String>[];

  @override
  Future<void> cancelNotification(String id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      List<NotificationEntity>.from(scheduled);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    scheduled.add(notification);
  }
}

class _StubGenerateSiDecision extends GenerateSiDecision {
  _StubGenerateSiDecision(this._result)
    : super(_FakeTaskRepository(), _FakeSiRepository());

  final SiDecisionEntity _result;

  @override
  Future<SiDecisionEntity> call([String input = '']) async => _result;
}
