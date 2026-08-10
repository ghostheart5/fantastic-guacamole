import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/core/eventing/event_bus.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/create_goal_usecase.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('provider orchestration', () {
    test('goals add fans out to logs, timeline, and event bus', () async {
      final _FakeGoalRepository goalRepository = _FakeGoalRepository();
      final _LogProbe logs = _LogProbe();
      final _TimelineProbe timeline = _TimelineProbe();
      final _FakeLocalMetricsAccumulator metrics =
          _FakeLocalMetricsAccumulator();
      final EventBus bus = EventBus();
      final List<GoalLifecycleEvent> emittedEvents = <GoalLifecycleEvent>[];
      final StreamSubscription<GoalLifecycleEvent> sub = bus
          .on<GoalLifecycleEvent>()
          .listen(emittedEvents.add);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          eventBusProvider.overrideWithValue(bus),
          domainGoalRepositoryProvider.overrideWithValue(goalRepository),
          getGoalsUseCaseProvider.overrideWithValue(GetGoals(goalRepository)),
          featureCreateGoalUseCaseProvider.overrideWithValue(
            CreateGoalUsecase(goalRepository),
          ),
          reminderOrchestratorServiceProvider.overrideWithValue(
            _buildReminderOrchestrator(),
          ),
          profileProvider.overrideWith(_TestProfileController.new),
          logsActionsProvider.overrideWith(
            (Ref ref) => _FakeLogsActions(ref, logs),
          ),
          timelineActionsProvider.overrideWith(
            (Ref ref) => _FakeTimelineActions(ref, timeline),
          ),
          localMetricsAccumulatorProvider.overrideWithValue(metrics),
        ],
      );
      addTearDown(() async {
        await sub.cancel();
        await bus.dispose();
        container.dispose();
      });

      await container
          .read(goalsProvider.notifier)
          .add(title: 'Ship mission control', description: 'Fan-out test');
      await _flushMicrotasks();

      expect(goalRepository.goals, hasLength(1));
      expect(logs.mirroredSources, contains('goal_created'));
      expect(timeline.mirroredEvents, isNotEmpty);
      expect(
        timeline.mirroredEvents.any(
          (TimelineEventEntity e) => e.type == TimelineEventType.goal,
        ),
        isTrue,
      );
      expect(emittedEvents, isNotEmpty);
      expect(emittedEvents.last.action, 'created');
      expect(metrics.checkpoints, contains('goal_created_event_emitted'));
    });

    test(
      'task create orchestrates save, timeline connect, lifecycle event',
      () async {
        final _FakeTaskRepository repository = _FakeTaskRepository();
        final _LogProbe logs = _LogProbe();
        final _TimelineProbe timeline = _TimelineProbe();
        final _FakeLocalMetricsAccumulator metrics =
            _FakeLocalMetricsAccumulator();
        final EventBus bus = EventBus();
        final List<TaskLifecycleEvent> emittedEvents = <TaskLifecycleEvent>[];
        final StreamSubscription<TaskLifecycleEvent> sub = bus
            .on<TaskLifecycleEvent>()
            .listen(emittedEvents.add);

        final ProviderContainer container = ProviderContainer(
          overrides: [
            eventBusProvider.overrideWithValue(bus),
            domainTaskRepositoryProvider.overrideWithValue(repository),
            createTaskUseCaseProvider.overrideWithValue(CreateTask(repository)),
            timelineActionsProvider.overrideWith(
              (Ref ref) => _FakeTimelineActions(ref, timeline),
            ),
            logsActionsProvider.overrideWith(
              (Ref ref) => _FakeLogsActions(ref, logs),
            ),
            localMetricsAccumulatorProvider.overrideWithValue(metrics),
          ],
        );
        addTearDown(() async {
          await sub.cancel();
          await bus.dispose();
          container.dispose();
        });

        final TaskEntity input = TaskEntity(
          id: 'task-1',
          title: '  Draft launch plan  ',
          createdAt: DateTime(2026, 1, 1),
          priority: 3,
          difficulty: 3,
          energyRequired: 3,
        );

        await container
            .read(taskActionsProvider)
            .createTask(input, actionSource: 'creator_task');
        await _flushMicrotasks();

        expect(repository.savedTasks, isNotEmpty);
        expect(repository.savedTasks.last.title, 'Draft launch plan');
        expect(timeline.connectedTasks, isNotEmpty);
        expect(timeline.connectedTasks.last.title, 'Draft launch plan');
        expect(logs.mirroredSources, contains('task_created'));
        expect(emittedEvents, isNotEmpty);
        expect(emittedEvents.last.action, 'created');
        expect(emittedEvents.last.actionSource, 'creator_task');
        expect(metrics.checkpoints, contains('task_created_event_emitted'));
      },
    );

    test(
      'task complete timeline action dedup suppresses repeated mutation',
      () async {
        final _FakeTaskRepository repository = _FakeTaskRepository(
          initialTasks: <TaskEntity>[
            TaskEntity(
              id: 'timeline-task-1',
              title: 'Close loop',
              createdAt: DateTime.utc(2026, 1, 1),
              priority: 3,
              difficulty: 2,
              energyRequired: 2,
            ),
          ],
        );

        final ProviderContainer container = ProviderContainer(
          overrides: [
            profileProvider.overrideWith(_TestProfileController.new),
            domainTaskRepositoryProvider.overrideWithValue(repository),
            completeTaskUseCaseProvider.overrideWithValue(
              CompleteTask(repository),
            ),
            tasksProvider.overrideWith((Ref ref) async => <Task>[]),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(taskActionsProvider)
            .completeTask(
              'timeline-task-1',
              actionSource: 'timeline',
              notify: false,
            );
        await container
            .read(taskActionsProvider)
            .completeTask(
              'timeline-task-1',
              actionSource: 'timeline',
              notify: false,
            );

        expect(repository.completedSaveCount, 1);
      },
    );
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ReminderOrchestratorService _buildReminderOrchestrator() {
  return ReminderOrchestratorService(
    preferences: _FakeSharedPrefsStore(),
    notifications: NotificationsService(_FakeNotificationRepository()),
    scheduler: NotificationScheduler(),
  );
}

class _FakeSharedPrefsStore implements SharedPrefsStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _data[key];

  @override
  Future<void> save(String key, String value) async {
    _data[key] = value;
  }
}

class _FakeNotificationRepository implements INotificationRepository {
  final List<NotificationEntity> scheduled = <NotificationEntity>[];

  @override
  Future<void> cancelNotification(String id) async {
    scheduled.removeWhere((NotificationEntity n) => n.id == id);
  }

  @override
  Future<void> delete(String id) async {
    scheduled.removeWhere((NotificationEntity n) => n.id == id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    return List<NotificationEntity>.from(scheduled);
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    scheduled.add(notification);
  }
}

class _FakeGoalRepository implements IGoalRepository {
  final List<GoalEntity> goals = <GoalEntity>[];

  @override
  Future<void> deleteGoal(String id) async {
    goals.removeWhere((GoalEntity g) => g.id == id);
  }

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.from(goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    goals.removeWhere((GoalEntity g) => g.id == goal.id);
    goals.add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    this.goals
      ..clear()
      ..addAll(goals);
  }
}

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository({List<TaskEntity>? initialTasks}) {
    if (initialTasks != null) {
      for (final TaskEntity task in initialTasks) {
        _tasks[task.id] = task;
      }
    }
  }

  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  final List<TaskEntity> savedTasks = <TaskEntity>[];
  int completedSaveCount = 0;

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
    savedTasks.add(task);
    if (task.isCompleted) {
      completedSaveCount += 1;
    }
  }
}

class _FakeLogsActions extends LogsActions {
  _FakeLogsActions(super.ref, this._probe);

  final _LogProbe _probe;

  @override
  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) async {
    _probe.mirroredSources.add(source);
  }

  @override
  Future<void> addCompletedTask({
    required String task,
    bool mirrored = false,
    bool updateInsights = false,
    bool syncSoulMap = false,
  }) async {}
}

class _FakeTimelineActions extends TimelineActions {
  _FakeTimelineActions(super.ref, this._probe);

  final _TimelineProbe _probe;

  @override
  Future<void> connectTask(TaskEntity task) async {
    _probe.connectedTasks.add(task);
  }

  @override
  Future<void> addMirroredEvent(TimelineEventEntity event) async {
    _probe.mirroredEvents.add(event);
  }
}

class _LogProbe {
  final List<String> mirroredSources = <String>[];
}

class _TimelineProbe {
  final List<TaskEntity> connectedTasks = <TaskEntity>[];
  final List<TimelineEventEntity> mirroredEvents = <TimelineEventEntity>[];
}

class _FakeLocalMetricsAccumulator extends LocalMetricsAccumulator {
  final List<String> checkpoints = <String>[];

  @override
  Future<void> recordAutomationCheckpoint(String checkpoint) async {
    checkpoints.add(checkpoint);
  }

  @override
  Future<void> recordTaskCreated() async {}

  @override
  Future<void> recordTaskCompleted() async {}
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() {
    return ProfileState(profileReady: true);
  }

  @override
  void addXP(int amount) {}
}
