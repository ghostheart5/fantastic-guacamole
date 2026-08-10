import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/event_bus.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_routines.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/create_goal_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/routines_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
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

  test(
    'automated user journey performs human-like end-to-end flow',
    () async {
      final _FakeAuthRepository authRepository = _FakeAuthRepository(
        initialSession: null,
      );
      final _FakeGoalRepository goalRepository = _FakeGoalRepository();
      final _FakeRoutineRepository routineRepository = _FakeRoutineRepository();
      final _FakeTaskRepository taskRepository = _FakeTaskRepository();
      final _TimelineProbe timeline = _TimelineProbe();
      final _LogProbe logs = _LogProbe();
      final _FakeLocalMetricsAccumulator metrics =
          _FakeLocalMetricsAccumulator();
      final EventBus bus = EventBus();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          eventBusProvider.overrideWithValue(bus),
          profileProvider.overrideWith(_TestProfileController.new),
          reminderOrchestratorServiceProvider.overrideWithValue(
            _buildReminderOrchestrator(),
          ),
          domainGoalRepositoryProvider.overrideWithValue(goalRepository),
          getGoalsUseCaseProvider.overrideWithValue(GetGoals(goalRepository)),
          featureCreateGoalUseCaseProvider.overrideWithValue(
            CreateGoalUsecase(goalRepository),
          ),
          domainRoutineRepositoryProvider.overrideWithValue(routineRepository),
          getRoutinesUseCaseProvider.overrideWithValue(
            GetRoutines(routineRepository),
          ),
          createRoutineUseCaseProvider.overrideWithValue(
            CreateRoutine(routineRepository),
          ),
          domainTaskRepositoryProvider.overrideWithValue(taskRepository),
          createTaskUseCaseProvider.overrideWithValue(
            CreateTask(taskRepository),
          ),
          completeTaskUseCaseProvider.overrideWithValue(
            CompleteTask(taskRepository),
          ),
          tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
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
        await bus.dispose();
        container.dispose();
      });

      // 1) Launch App
      expect(container.read(appFlowProvider), AppView.nexus);

      // 2) Login
      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            email: 'journey@example.com',
            password: 'Password123',
          );
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );

      // 3) Create Goal
      await container
          .read(goalsProvider.notifier)
          .add(
            title: 'Journey Goal',
            description: 'Reach mission-ready state.',
          );

      // 4) Create Habit
      final RoutineEntity habit = RoutineEntity(
        id: 'habit-journey-1',
        name: 'Daily Focus Sprint',
        createdAt: DateTime.now(),
        cadence: RoutineCadence.daily,
        targetCount: 1,
      );
      await container.read(routinesProvider.notifier).addHabit(habit);

      // 5) Create Task
      final TaskEntity task = TaskEntity(
        id: 'task-journey-1',
        title: 'Ship milestone task',
        createdAt: DateTime.now(),
        priority: 3,
        difficulty: 2,
        energyRequired: 2,
      );
      await container
          .read(taskActionsProvider)
          .createTask(task, actionSource: 'automated_journey');

      // 6) Create Note
      await container
          .read(logsActionsProvider)
          .addStandaloneEntry(
            source: 'note',
            message: 'Captured mission context for SI.',
          );

      // 7) Open Timeline
      container.read(appFlowProvider.notifier).toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);

      // 8) Open SI Console
      container.read(appFlowProvider.notifier).toConsole();
      expect(container.read(appFlowProvider), AppView.console);

      // 9) Open Profile
      container.read(appFlowProvider.notifier).toProfile();
      expect(container.read(appFlowProvider), AppView.profile);

      // 10) Open Settings
      container.read(appFlowProvider.notifier).toSettings();
      expect(container.read(appFlowProvider), AppView.settings);

      // 11) Return to Nexus
      container.read(appFlowProvider.notifier).toNexus();
      expect(container.read(appFlowProvider), AppView.nexus);

      // 12) Verify values exist
      final List<GoalEntity> goals = container.read(goalsProvider);
      final List<RoutineEntity> habits = container.read(routinesProvider);

      expect(
        goals.any((GoalEntity goal) => goal.title == 'Journey Goal'),
        isTrue,
      );
      expect(
        habits.any((RoutineEntity item) => item.name == 'Daily Focus Sprint'),
        isTrue,
      );
      expect(
        taskRepository.savedTasks.any(
          (TaskEntity item) => item.id == 'task-journey-1',
        ),
        isTrue,
      );
      expect(
        logs.notes.any((String note) => note.contains('mission context')),
        isTrue,
      );
      expect(
        timeline.connectedTasks.map((TaskEntity item) => item.id),
        contains('task-journey-1'),
      );

      // 13) Logout
      await container.read(authControllerProvider.notifier).signOut();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    },
    tags: <String>['full', 'journey'],
  );
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

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required AuthSessionEntity? initialSession})
    : _session = initialSession;

  final StreamController<Result<AuthSessionEntity?>> _sessionStream =
      StreamController<Result<AuthSessionEntity?>>.broadcast();
  AuthSessionEntity? _session;

  @override
  Stream<Result<AuthSessionEntity?>> watchSession() => _sessionStream.stream;

  @override
  Future<Result<AuthSessionEntity?>> getCurrentSession() async {
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthUserEntity?>> getCurrentUser() async {
    return Result<AuthUserEntity?>.success(_session?.user);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = _activeSession('journey-user', email.value, 'token-journey');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = _activeSession('journey-signup', email.value, 'token-signup');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() async {
    _session = _activeSession(
      'journey-google',
      'journey.google@example.com',
      'token-google',
    );
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<void>> sendPasswordReset({required EmailAddress email}) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> refreshSession() async {
    _session = _activeSession(
      'journey-refresh',
      'journey.refresh@example.com',
      'token-refresh',
    );
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    _session = null;
    _sessionStream.add(const Result<AuthSessionEntity?>.success(null));
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteAccount({required PasswordValue password}) async {
    _session = null;
    _sessionStream.add(const Result<AuthSessionEntity?>.success(null));
    return const Result<void>.success(null);
  }
}

AuthSessionEntity _activeSession(String id, String email, String token) {
  final DateTime now = DateTime.now();
  return AuthSessionEntity(
    accessToken: token,
    refreshToken: 'refresh-$id',
    issuedAt: now,
    expiresAt: now.add(const Duration(hours: 2)),
    user: AuthUserEntity(
      id: id,
      email: email,
      displayName: 'Journey User',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
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
  Future<void> saveGoals(List<GoalEntity> next) async {
    goals
      ..clear()
      ..addAll(next);
  }
}

class _FakeRoutineRepository implements IRoutineRepository {
  final List<RoutineEntity> routines = <RoutineEntity>[];

  @override
  Future<void> deleteRoutine(String id) async {
    routines.removeWhere((RoutineEntity r) => r.id == id);
  }

  @override
  List<RoutineEntity> getRoutines() => List<RoutineEntity>.from(routines);

  @override
  Future<void> saveRoutine(RoutineEntity routine) async {
    routines.removeWhere((RoutineEntity r) => r.id == routine.id);
    routines.add(routine);
  }

  @override
  Future<void> saveRoutines(List<RoutineEntity> next) async {
    routines
      ..clear()
      ..addAll(next);
  }
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  final List<TaskEntity> savedTasks = <TaskEntity>[];

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
  }
}

class _FakeTimelineActions extends TimelineActions {
  _FakeTimelineActions(super.ref, this._probe);

  final _TimelineProbe _probe;

  @override
  Future<void> connectTask(TaskEntity task) async {
    _probe.connectedTasks.add(task);
  }

  @override
  Future<void> connectGoal(GoalEntity goal) async {
    _probe.connectedGoals.add(goal);
  }

  @override
  Future<void> connectHabit(HabitEntity habit) async {
    _probe.connectedHabits.add(habit);
  }

  @override
  Future<void> addMirroredEvent(TimelineEventEntity event) async {
    _probe.mirroredEvents.add(event);
  }
}

class _TimelineProbe {
  final List<TaskEntity> connectedTasks = <TaskEntity>[];
  final List<GoalEntity> connectedGoals = <GoalEntity>[];
  final List<HabitEntity> connectedHabits = <HabitEntity>[];
  final List<TimelineEventEntity> mirroredEvents = <TimelineEventEntity>[];
}

class _FakeLogsActions extends LogsActions {
  _FakeLogsActions(super.ref, this._probe);

  final _LogProbe _probe;

  @override
  Future<void> addStandaloneEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) async {
    if (source == 'note') {
      _probe.notes.add(message);
    }
  }

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

class _LogProbe {
  final List<String> notes = <String>[];
  final List<String> mirroredSources = <String>[];
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
