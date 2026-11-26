import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits until the provider has a settled value (not loading).
Future<PatternsResult> settled(ProviderContainer container) async {
  for (int i = 0; i < 500; i++) {
    final AsyncValue<PatternsResult> v = container.read(patternsProvider);
    if (v.hasError) Error.throwWithStackTrace(v.error!, v.stackTrace!);
    if (v.hasValue && !v.isLoading) return v.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('patterns never settled');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 12, 1, 10);

  TaskEntity finished(String id, String title, int daysAgo) => TaskEntity(
    id: id,
    title: title,
    createdAt: DateTime(2026, 10, 1),
    isCompleted: true,
    completedAt: DateTime(2026, 12, 1 - daysAgo, 9),
  );

  TaskEntity skippedTask(String id, String title, int daysAgo) => TaskEntity(
    id: id,
    title: title,
    createdAt: DateTime(2026, 10, 1),
    isSkipped: true,
    skippedAt: DateTime(2026, 12, 1 - daysAgo, 9),
  );

  HabitEntity walk(String id, String title) =>
      HabitEntity(id: id, title: title, createdAt: DateTime(2026, 10, 1));

  late AccountStorageScope scope;
  late Map<String, List<TaskEntity>> tasksByUser;
  late Map<String, List<HabitEntity>> habitsByUser;
  late _MemoryPrefs prefs;
  void Function()? onTaskRead;
  // When set, the account scope follows the auth boundary like the real one.
  bool boundaryDriven = false;
  DateTime Function() clock = () => DateTime(2026, 12, 1, 10);

  ProviderContainer build() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) {
          if (!boundaryDriven) return scope;
          final AuthSessionBoundary b = ref.watch(authSessionBoundaryProvider);
          return b.userId != null && b.isStorageReady && !b.isTransitioning
              ? AccountStorageScope.authenticated(b.userId!)
              : const AccountStorageScope.unsafe();
        }),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        patternsClockProvider.overrideWithValue(() => clock()),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        siStateProvider.overrideWith(_FixedSiStateController.new),
        learningProvider.overrideWith(_FixedLearningController.new),
        profileProvider.overrideWith(_TestProfileController.new),
        decisionOutcomeRepositoryProvider.overrideWithValue(null),
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        // Like the real repositories, these follow the account scope.
        domainTaskRepositoryProvider.overrideWith((ref) {
          final String? user = ref.watch(accountStorageScopeProvider).rawUserId;
          return _Tasks(
            tasksByUser.putIfAbsent(user ?? '', () => <TaskEntity>[]),
            () => onTaskRead?.call(),
          );
        }),
        // The durable path stamps a fixed instant (the real one needs real
        // stores); TaskActions.completeTask itself is the real code.
        completeTaskUseCaseProvider.overrideWith((ref) {
          final ITaskRepository repository = ref.watch(
            domainTaskRepositoryProvider,
          );
          return CompleteTask(
            repository,
            durableMutation: (String id) async {
              final TaskEntity? task = await repository.getTaskById(id);
              if (task == null) return CompletionMutationOutcome.conflict;
              await repository.saveTask(
                task.copyWith(isCompleted: true, completedAt: clock()),
              );
              return CompletionMutationOutcome.applied;
            },
          );
        }),
        domainHabitRepositoryProvider.overrideWith((ref) {
          final String? user = ref.watch(accountStorageScopeProvider).rawUserId;
          return _Habits(habitsByUser.putIfAbsent(user ?? '', () => []));
        }),
        habitOccurrenceCoordinatorProvider.overrideWith((ref) {
          final AccountStorageScope current = ref.watch(
            accountStorageScopeProvider,
          );
          final repository = ref.watch(habitOccurrenceRepositoryProvider);
          if (repository == null) return null;
          return HabitOccurrenceCoordinator(
            scope: current,
            habitRepository: ref.watch(domainHabitRepositoryProvider),
            occurrenceRepository: repository,
            outcomeRepository: _Outcomes(),
            learningPaused: () async => true,
            clock: () => clock(),
          );
        }),
        reminderOrchestratorServiceProvider.overrideWithValue(
          ReminderOrchestratorService(
            preferences: _DisabledPreferences(),
            notifications: NotificationsService(_NoopNotifications()),
            scheduler: NotificationScheduler(),
            accountScope: null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(patternsProvider, (_, _) {});
    return container;
  }

  setUp(() {
    scope = AccountStorageScope.authenticated('account-a');
    boundaryDriven = false;
    clock = () => now;
    prefs = _MemoryPrefs();
    onTaskRead = null;
    tasksByUser = <String, List<TaskEntity>>{
      'account-a': <TaskEntity>[
        finished('a1', 'Tax return', 1),
        skippedTask('a2', 'Tax skipped', 2),
      ],
      'account-b': <TaskEntity>[
        finished('b1', 'Paint fence', 1),
        skippedTask('b2', 'Fence skipped', 2),
      ],
    };
    habitsByUser = <String, List<HabitEntity>>{
      'account-a': <HabitEntity>[walk('ha', 'Walk A')],
      'account-b': <HabitEntity>[walk('hb', 'Stretch B')],
    };
  });

  test('range starts at 7, accepts 30 and refuses anything else', () {
    final ProviderContainer container = build();
    expect(container.read(patternsRangeDaysProvider), 7);
    container.read(patternsRangeDaysProvider.notifier).set(30);
    expect(container.read(patternsRangeDaysProvider), 30);
    expect(
      () => container.read(patternsRangeDaysProvider.notifier).set(14),
      throwsArgumentError,
    );
    expect(container.read(patternsRangeDaysProvider), 30);
  });

  test('reads full history for the account and follows the range', () async {
    final ProviderContainer container = build();
    final PatternsResult seven = await settled(container);
    expect(seven.rangeDays, 7);
    expect(seven.habits.value.single.title, 'Walk A');
    expect(seven.trend.value.tasksFinished, 1);
    container.read(patternsRangeDaysProvider.notifier).set(30);
    final PatternsResult thirty = await settled(container);
    expect(thirty.rangeDays, 30);
    expect(thirty.trend.value.buckets, hasLength(4));
  });

  test('switching from account A to B shows none of A', () async {
    final ProviderContainer container = build();
    final PatternsResult a = await settled(container);
    expect(a.habits.value.single.title, 'Walk A');

    scope = AccountStorageScope.authenticated('account-b');
    container.invalidate(accountStorageScopeProvider);
    final PatternsResult b = await settled(container);
    expect(b.habits.value.map((h) => h.title), <String>['Stretch B']);
    expect(b.habits.value.map((h) => h.habitId), isNot(contains('ha')));
    expect(b.trend.value.tasksFinished, 1);
    expect(b.missed.skippedTasks.value.map((r) => r.title), <String>[
      'Fence skipped',
    ]);
  });

  test('the real switch path: boundary generation and storage state', () async {
    boundaryDriven = true;
    final ProviderContainer container = build();
    final _Boundary boundary =
        container.read(authSessionBoundaryProvider.notifier) as _Boundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final PatternsResult a = await settled(container);
    expect(a.habits.value.map((h) => h.title), <String>['Walk A']);

    // Sign-out and sign-in as B: transitioning, storage not ready, then ready
    // with a new generation. The fence invalidates the habit list.
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
    );
    container.invalidate(habitsProvider);
    final PatternsResult during = await settled(container);
    expect(during.habits.value, isEmpty);
    expect(during.trend.value.tasksFinished, 0);

    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final PatternsResult b = await settled(container);
    expect(b.habits.value.map((h) => h.title), <String>['Stretch B']);
    expect(b.missed.skippedTasks.value.map((r) => r.title), <String>[
      'Fence skipped',
    ]);
  });

  test('no listener ever sees account A while B loads', () async {
    boundaryDriven = true;
    final ProviderContainer container = build();
    final _Boundary boundary =
        container.read(authSessionBoundaryProvider.notifier) as _Boundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    expect(
      (await settled(container)).habits.value.map((h) => h.title),
      <String>['Walk A'],
    );

    bool showsA(AsyncValue<PatternsResult> v) {
      final PatternsResult? r = v.value;
      return r != null &&
          (r.habits.value.any((h) => h.title == 'Walk A') ||
              r.missed.skippedTasks.value.any((t) => t.title == 'Tax skipped'));
    }

    final List<AsyncValue<PatternsResult>> seen =
        <AsyncValue<PatternsResult>>[];
    container.listen(patternsProvider, (_, next) => seen.add(next));

    // Same steps as a real sign-out and sign-in as B, reading the state a
    // screen would read after each one.
    final List<AsyncValue<PatternsResult>> reads =
        <AsyncValue<PatternsResult>>[];
    void move(AuthSessionBoundary next) {
      boundary.moveTo(next);
      container.invalidate(habitsProvider);
      reads.add(container.read(patternsProvider));
    }

    move(
      const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
    );
    move(
      const AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final PatternsResult b = await settled(container);
    await pumpEventQueue();
    reads.add(container.read(patternsProvider));

    expect(b.habits.value.map((h) => h.title), <String>['Stretch B']);
    expect(seen.where(showsA), isEmpty);
    expect(reads.where(showsA), isEmpty);
  });

  test('an account change during the read gives nothing of it', () async {
    late ProviderContainer container;
    bool switched = false;
    onTaskRead = () {
      if (switched) return;
      switched = true;
      scope = AccountStorageScope.authenticated('account-b');
      container.invalidate(accountStorageScopeProvider);
    };
    container = build();
    final PatternsResult stale = await settled(container);
    // The read that started for account A ends after the switch: whatever it
    // shows is empty or account B's, never A's.
    expect(
      stale.habits.value.map((h) => h.title),
      everyElement(equals('Stretch B')),
    );
    expect(
      stale.missed.skippedTasks.value.map((r) => r.title),
      isNot(contains('Tax skipped')),
    );
    expect(switched, isTrue);
    final PatternsResult next = await settled(container);
    expect(next.habits.value.map((h) => h.title), <String>['Stretch B']);
  });

  test('storage that is not writable gives the empty result', () async {
    scope = const AccountStorageScope.unsafe();
    final ProviderContainer container = build();
    final PatternsResult r = await settled(container);
    expect(r.habits.value, isEmpty);
    expect(r.habits.evidence.enough, isFalse);
    expect(r.trend.value.tasksFinished, 0);
    expect(r.whenDone.evidence.enough, isFalse);
  });

  test('a habit check-in updates the result', () async {
    final ProviderContainer container = build();
    final PatternsResult before = await settled(container);
    expect(before.habits.value.single.consistency.completed, 0);
    expect(before.trend.value.habitCheckIns, 0);

    await container.read(habitsProvider.notifier).completeHabit('ha');

    final PatternsResult after = await settled(container);
    expect(after.habits.value.single.consistency.completed, 1);
    expect(after.habits.value.single.consistency.checkedInThisPeriod, isTrue);
    expect(after.trend.value.habitCheckIns, 1);
  });

  group('stays live while it is watched', () {
    test('a task finished through the task actions shows up', () async {
      tasksByUser['account-a'] = <TaskEntity>[
        TaskEntity(id: 'open', title: 'Open', createdAt: DateTime(2026, 10, 1)),
      ];
      final ProviderContainer container = build();
      final PatternsResult before = await settled(container);
      expect(before.trend.value.tasksFinished, 0);

      await container.read(taskActionsProvider).completeTask('open');
      await pumpEventQueue();

      final PatternsResult after = await settled(container);
      expect(after.trend.value.tasksFinished, 1);
    });

    test('a habit added through the habit list shows up', () async {
      final ProviderContainer container = build();
      await settled(container);
      await container.read(habitsProvider.future);

      await container.read(habitsProvider.notifier).addHabit(title: 'Stretch');
      await pumpEventQueue();

      final PatternsResult after = await settled(container);
      expect(
        after.habits.value.map((h) => h.title),
        containsAll(<String>['Walk A', 'Stretch']),
      );
    });

    test('pausing a habit takes it out', () async {
      final ProviderContainer container = build();
      await settled(container);
      await container.read(habitsProvider.future);

      await container.read(habitsProvider.notifier).toggleHabit('ha');
      await pumpEventQueue();

      final PatternsResult after = await settled(container);
      expect(after.habits.value, isEmpty);
    });

    testWidgets('the local day changing refreshes it', (tester) async {
      DateTime moment = DateTime(2026, 12, 1, 23, 0);
      clock = () => moment;
      final ProviderContainer container = build();
      // Fake time: reads finish as the test pumps.
      Future<PatternsResult> settle() async {
        for (int i = 0; i < 50; i++) {
          final AsyncValue<PatternsResult> v = container.read(patternsProvider);
          if (v.hasValue && !v.isLoading) return v.requireValue;
          await tester.pump(const Duration(milliseconds: 1));
        }
        throw StateError('patterns never settled');
      }

      expect((await settle()).now.day, 1);

      moment = DateTime(2026, 12, 2, 0, 0, 5);
      await tester.pump(const Duration(hours: 1, seconds: 2));
      expect((await settle()).now.day, 2);
      // The pending day-change timer goes with the provider.
      container.dispose();
    });

    test('the day change delay is until the next local midnight', () {
      expect(
        patternsDayRolloverDelay(DateTime(2026, 12, 1, 23, 0)),
        const Duration(hours: 1, seconds: 1),
      );
      expect(
        patternsDayRolloverDelay(DateTime(2026, 12, 1, 0, 0)),
        const Duration(hours: 24, seconds: 1),
      );
    });
  });
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.1, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> addXP(int amount) async {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-scope',
    isTransitioning: false,
    isStorageReady: true,
  );

  void moveTo(AuthSessionBoundary next) => state = next;
}

class _Tasks implements ITaskRepository {
  _Tasks(this._records, this._onRead);
  final List<TaskEntity> _records;
  final void Function() _onRead;

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    final List<TaskEntity> values = List<TaskEntity>.of(_records);
    await Future<void>.delayed(Duration.zero);
    _onRead();
    return values;
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      _records.where((TaskEntity t) => t.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {
    final int i = _records.indexWhere((TaskEntity t) => t.id == task.id);
    if (i >= 0) {
      _records[i] = task;
    } else {
      _records.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async =>
      _records.removeWhere((TaskEntity t) => t.id == id);
}

class _Habits implements IHabitRepository {
  _Habits(this._records);
  final List<HabitEntity> _records;

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(_records);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    _records
      ..clear()
      ..addAll(habits);
  }
}

class _Outcomes implements IDecisionOutcomeRepository {
  @override
  Future<List<DecisionOutcomeEntity>> load() async =>
      const <DecisionOutcomeEntity>[];

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async {}
}

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

final class _DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => 'false';
  @override
  Future<void> save(String key, String value) async {}
}

final class _NoopNotifications implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
