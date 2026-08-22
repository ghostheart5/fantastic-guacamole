import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/event_bus.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Authentication', () {
    test('email login, logout, and session restore', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        initialSession: _activeSession(
          'restore-user',
          'restore@example.com',
          'restore-token',
        ),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(
        container.read(authControllerProvider).user?.email,
        'restore@example.com',
      );

      await container.read(authControllerProvider.notifier).signOut();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'pilot@example.com', password: 'Password123');
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(
        container.read(authControllerProvider).user?.email,
        'pilot@example.com',
      );
    }, tags: <String>['full']);
  });

  group('Onboarding', () {
    test('complete mission zero progression path', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(missionStateProvider.notifier).reset();
      await container
          .read(missionStateProvider.notifier)
          .reportFirstItemCreated();
      await container.read(missionStateProvider.notifier).reportCreatorOpened();
      await container
          .read(missionStateProvider.notifier)
          .reportTimelineOpened();

      final MissionState mission = container
          .read(missionStateProvider)
          .requireValue;
      expect(mission.activeMissionId, MissionId.complete);
      expect(mission.isCompletionBannerActive, isTrue);
      expect(
        mission.statusOf(MissionId.createFirstGoal),
        MissionStatus.completed,
      );
      expect(
        mission.statusOf(MissionId.configureFirstItem),
        MissionStatus.completed,
      );
      expect(mission.statusOf(MissionId.openTimeline), MissionStatus.completed);
    }, tags: <String>['full']);

    testWidgets('skip attempt marks onboarding complete', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(_TestProfileController.new),
          intelligenceStateProvider.overrideWithValue(_unauthenticatedRuntime),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('SKIP').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(onboardingCompleteProvider), isTrue);
      expect(
        container.read(onboardingStatusProvider),
        OnboardingStatus.complete,
      );
    }, tags: <String>['full']);

    testWidgets(
      'progress tracking stores onboarding step after NEXT',
      (WidgetTester tester) async {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            profileProvider.overrideWith(_TestProfileController.new),
            intelligenceStateProvider.overrideWithValue(
              _unauthenticatedRuntime,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: OnboardingScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 500));

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(onboardingStepStorageKey), 1);
      },
      tags: <String>['full'],
    );
  });

  group('Core User Flow', () {
    test(
      'open app, create task, complete task, and see dashboard update',
      () async {
        final _FakeTaskRepository taskRepository = _FakeTaskRepository();
        final _TimelineProbe timeline = _TimelineProbe();
        final _FakeLocalMetricsAccumulator metrics =
            _FakeLocalMetricsAccumulator();
        final EventBus bus = EventBus();
        final AccountStorageScope taskScope = AccountStorageScope.authenticated(
          'core-flow-user',
        );
        final _MemoryTaskOccurrenceRepository occurrences =
            _MemoryTaskOccurrenceRepository();

        final ProviderContainer container = ProviderContainer(
          overrides: [
            eventBusProvider.overrideWithValue(bus),
            profileProvider.overrideWith(_TestProfileController.new),
            domainTaskRepositoryProvider.overrideWithValue(taskRepository),
            accountStorageScopeProvider.overrideWithValue(taskScope),
            taskOccurrenceCoordinatorProvider.overrideWithValue(
              TaskOccurrenceCoordinator(
                scope: taskScope,
                taskRepository: taskRepository,
                occurrenceRepository: occurrences,
              ),
            ),
            createTaskUseCaseProvider.overrideWithValue(
              CreateTask(taskRepository),
            ),
            completeTaskUseCaseProvider.overrideWithValue(
              CompleteTask(taskRepository),
            ),
            timelineActionsProvider.overrideWith(
              (Ref ref) => _FakeTimelineActions(ref, timeline),
            ),
            logsActionsProvider.overrideWith(
              (Ref ref) => _FakeLogsActions(ref),
            ),
            localMetricsAccumulatorProvider.overrideWithValue(metrics),
            tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
          ],
        );
        addTearDown(() async {
          await bus.dispose();
          container.dispose();
        });

        // 1) Open app
        expect(container.read(appFlowProvider), AppView.nexus);

        final int beforeCompleted = container
            .read(nexusStartupSummaryProvider)
            .completedToday;

        // 2) Create task
        final TaskEntity task = TaskEntity(
          id: 'core-flow-1',
          title: 'Ship integration test milestone',
          createdAt: DateTime(2026, 1, 1),
          priority: 3,
          difficulty: 2,
          energyRequired: 2,
        );
        await container
            .read(taskActionsProvider)
            .createTask(task, actionSource: 'core_user_flow');

        expect(
          taskRepository.savedTasks.map((TaskEntity item) => item.id),
          contains('core-flow-1'),
        );

        // 3) Complete task
        await container
            .read(taskActionsProvider)
            .completeTask(
              'core-flow-1',
              notify: false,
              actionSource: 'core_user_flow',
            );
        await _flushMicrotasks();

        // 4) Dashboard update (Nexus summary)
        final int afterCompleted = container
            .read(nexusStartupSummaryProvider)
            .completedToday;
        expect(afterCompleted, beforeCompleted + 1);
        expect(timeline.connectedTasks, isNotEmpty);
        expect(metrics.checkpoints, contains('task_completed_event_emitted'));
      },
      tags: <String>['full'],
    );
  });
}

class _MemoryTaskOccurrenceRepository extends TaskOccurrenceRepository {
  _MemoryTaskOccurrenceRepository() : super.unavailable();

  final Map<String, TaskOccurrence> _values = <String, TaskOccurrence>{};

  @override
  Future<void> cancelAndDrain() async {}

  @override
  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async => _values[TaskOccurrence.occurrenceId(taskId, occurrenceKey)];

  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      _values.values
          .where((TaskOccurrence value) => value.taskId == taskId)
          .toList(growable: false);

  @override
  Future<void> save(TaskOccurrence occurrence) async {
    _values[occurrence.id] = occurrence;
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const IntelligenceState _unauthenticatedRuntime = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'test',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: false,
    mockLoginEnabled: false,
    paywallDisabled: false,
    testerFullAccess: false,
  ),
  auth: AuthStateSnapshot(hasMockSession: false, hasAuthenticatedUser: false),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

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
    _session = _activeSession('user-1', email.value, 'token-login');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = _activeSession('user-signup', email.value, 'token-signup');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() async {
    _session = _activeSession(
      'user-google',
      'google@example.com',
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
      'user-refresh',
      'refresh@example.com',
      'token-refreshed',
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
      displayName: 'Pilot',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
}

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository();

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

class _FakeLogsActions extends LogsActions {
  _FakeLogsActions(super.ref);

  @override
  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
  }) async {}

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
  Future<void> addMirroredEvent(TimelineEventEntity event) async {}
}

class _TimelineProbe {
  final List<TaskEntity> connectedTasks = <TaskEntity>[];
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

  @override
  void ensureProfile({String? preferredName}) {
    state = state.copyWith(
      name: (preferredName?.trim().isNotEmpty ?? false)
          ? preferredName!.trim()
          : 'Creator',
      profileReady: true,
    );
  }
}
