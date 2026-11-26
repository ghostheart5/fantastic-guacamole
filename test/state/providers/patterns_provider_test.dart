import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
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

  HabitEntity walk(String id, String title) =>
      HabitEntity(id: id, title: title, createdAt: DateTime(2026, 10, 1));

  late AccountStorageScope scope;
  late Map<String, List<TaskEntity>> tasksByUser;
  late Map<String, List<HabitEntity>> habitsByUser;
  late _MemoryPrefs prefs;
  void Function()? onTaskRead;

  ProviderContainer build() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        patternsClockProvider.overrideWithValue(() => now),
        decisionOutcomeRepositoryProvider.overrideWithValue(null),
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        // Like the real repositories, these follow the account scope.
        domainTaskRepositoryProvider.overrideWith((ref) {
          ref.watch(accountStorageScopeProvider);
          return _Tasks(
            () => tasksByUser[scope.rawUserId] ?? const <TaskEntity>[],
            () => onTaskRead?.call(),
          );
        }),
        domainHabitRepositoryProvider.overrideWith((ref) {
          ref.watch(accountStorageScopeProvider);
          return _Habits(
            () => habitsByUser[scope.rawUserId] ?? const <HabitEntity>[],
          );
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
            clock: () => now,
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
    prefs = _MemoryPrefs();
    onTaskRead = null;
    tasksByUser = <String, List<TaskEntity>>{
      'account-a': <TaskEntity>[finished('a1', 'Tax return', 1)],
      'account-b': <TaskEntity>[finished('b1', 'Paint fence', 1)],
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
    final PatternsResult seven = await container.read(patternsProvider.future);
    expect(seven.rangeDays, 7);
    expect(seven.habits.value.single.title, 'Walk A');
    expect(seven.trend.value.tasksFinished, 1);
    container.read(patternsRangeDaysProvider.notifier).set(30);
    final PatternsResult thirty = await container.read(patternsProvider.future);
    expect(thirty.rangeDays, 30);
    expect(thirty.trend.value.buckets, hasLength(4));
  });

  test('switching from account A to B shows none of A', () async {
    final ProviderContainer container = build();
    final PatternsResult a = await container.read(patternsProvider.future);
    expect(a.habits.value.single.title, 'Walk A');

    scope = AccountStorageScope.authenticated('account-b');
    container.invalidate(accountStorageScopeProvider);
    final PatternsResult b = await container.read(patternsProvider.future);
    expect(b.habits.value.map((h) => h.title), <String>['Stretch B']);
    expect(b.habits.value.map((h) => h.habitId), isNot(contains('ha')));
    expect(b.trend.value.tasksFinished, 1);
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
    final PatternsResult stale = await container.read(patternsProvider.future);
    // The read that started for account A ends after the switch: whatever it
    // shows is empty or account B's, never A's.
    expect(
      stale.habits.value.map((h) => h.title),
      everyElement(equals('Stretch B')),
    );
    expect(switched, isTrue);
    final PatternsResult next = await container.read(patternsProvider.future);
    expect(next.habits.value.map((h) => h.title), <String>['Stretch B']);
  });

  test('storage that is not writable gives the empty result', () async {
    scope = const AccountStorageScope.unsafe();
    final ProviderContainer container = build();
    final PatternsResult r = await container.read(patternsProvider.future);
    expect(r.habits.value, isEmpty);
    expect(r.habits.evidence.enough, isFalse);
    expect(r.trend.value.tasksFinished, 0);
    expect(r.whenDone.evidence.enough, isFalse);
  });

  test('a habit check-in updates the result', () async {
    final ProviderContainer container = build();
    final PatternsResult before = await container.read(patternsProvider.future);
    expect(before.habits.value.single.consistency.completed, 0);
    expect(before.trend.value.habitCheckIns, 0);

    await container.read(habitsProvider.notifier).completeHabit('ha');

    final PatternsResult after = await container.read(patternsProvider.future);
    expect(after.habits.value.single.consistency.completed, 1);
    expect(after.habits.value.single.consistency.checkedInThisPeriod, isTrue);
    expect(after.trend.value.habitCheckIns, 1);
  });
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-scope',
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _Tasks implements ITaskRepository {
  _Tasks(this._read, this._onRead);
  final List<TaskEntity> Function() _read;
  final void Function() _onRead;

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    final List<TaskEntity> values = _read();
    await Future<void>.delayed(Duration.zero);
    _onRead();
    return values;
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}

class _Habits implements IHabitRepository {
  _Habits(this._read);
  final List<HabitEntity> Function() _read;

  @override
  Future<List<HabitEntity>> getHabits() async => _read();

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
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
