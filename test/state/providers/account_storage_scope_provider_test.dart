import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const User user = User(
    id: 'account-a',
    email: 'a@example.test',
    emailVerified: true,
  );

  test('storage opens only for a ready matching account boundary', () {
    final AccountStorageScope ready = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope transitioning = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: true,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope mismatched = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope blocked = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
        blockingIssue: 'ownership unknown',
      ),
    );

    expect(ready.isWritable, isTrue);
    expect(ready.rawUserId, 'account-a');
    expect(transitioning.state, AccountStorageScopeState.unsafe);
    expect(mismatched.state, AccountStorageScopeState.unsafe);
    expect(blocked.state, AccountStorageScopeState.unsafe);
    expect(
      resolveAccountStorageScope(
        user: null,
        boundary: const AuthSessionBoundary.initial(),
      ).state,
      AccountStorageScopeState.signedOut,
    );
  });

  test('markerless data is never silently assigned to a signed-in user', () {
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: null,
        hasUnownedData: true,
      ),
      isTrue,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: null,
        hasUnownedData: false,
      ),
      isFalse,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: 'account-a',
        storedUserId: null,
        hasUnownedData: true,
      ),
      isFalse,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: 'account-a',
        hasUnownedData: true,
      ),
      isFalse,
    );
  });

  test('stale generations cannot reopen or overwrite the boundary', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AuthSessionBoundaryNotifier notifier = container.read(
      authSessionBoundaryProvider.notifier,
    );

    final int accountA = notifier.begin(
      userId: 'account-a',
      isTransitioning: true,
    );
    final int accountB = notifier.begin(
      userId: 'account-b',
      isTransitioning: true,
    );
    notifier.markStorageReady(accountA);
    notifier.complete(accountA);

    expect(container.read(authSessionBoundaryProvider).userId, 'account-b');
    expect(container.read(authSessionBoundaryProvider).isStorageReady, isFalse);

    notifier.markStorageReady(accountB);
    notifier.complete(accountB);
    final AuthSessionBoundary ready = container.read(
      authSessionBoundaryProvider,
    );
    expect(ready.userId, 'account-b');
    expect(ready.isStorageReady, isTrue);
    expect(ready.isTransitioning, isFalse);
  });

  test('ownership block exposes claim, not destructive discard', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AuthSessionBoundaryNotifier notifier = container.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = notifier.begin(
      userId: 'account-a',
      isTransitioning: true,
    );

    notifier.block(
      generation,
      issue: 'ownership unknown',
      canRecoverBySigningOut: true,
      canClaimPreservedData: true,
    );

    final AuthSessionBoundary blocked = container.read(
      authSessionBoundaryProvider,
    );
    expect(blocked.isStorageReady, isFalse);
    expect(blocked.blockingIssue, 'ownership unknown');
    expect(blocked.canClaimPreservedData, isTrue);
    expect(blocked.canRecoverBySigningOut, isTrue);
  });

  test('domain task repository follows an authenticated scope transition', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_mutableAccountStorageScopeProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    final Object signedOutRepository = container.read(
      domainTaskRepositoryProvider,
    );
    final Object signedOutUseCase = container.read(getTasksUseCaseProvider);
    container.read(_mutableAccountStorageScopeProvider.notifier).authenticate();
    final Object authenticatedRepository = container.read(
      domainTaskRepositoryProvider,
    );
    final Object authenticatedUseCase = container.read(getTasksUseCaseProvider);

    expect(authenticatedRepository, isNot(same(signedOutRepository)));
    expect(authenticatedUseCase, isNot(same(signedOutUseCase)));
    expect(
      container.read(taskRepositoryProvider),
      same(authenticatedRepository),
    );
  });

  test('goal repository and use cases follow an account scope transition', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_mutableAccountStorageScopeProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    final List<Object> signedOutDependencies = <Object>[
      container.read(domainGoalRepositoryProvider),
      container.read(getGoalsUseCaseProvider),
      container.read(createGoalUseCaseProvider),
      container.read(updateGoalUseCaseProvider),
      container.read(deleteGoalUseCaseProvider),
      container.read(completeGoalUseCaseProvider),
      container.read(saveGoalsUseCaseProvider),
    ];

    container.read(_mutableAccountStorageScopeProvider.notifier).authenticate();

    final List<Object> authenticatedDependencies = <Object>[
      container.read(domainGoalRepositoryProvider),
      container.read(getGoalsUseCaseProvider),
      container.read(createGoalUseCaseProvider),
      container.read(updateGoalUseCaseProvider),
      container.read(deleteGoalUseCaseProvider),
      container.read(completeGoalUseCaseProvider),
      container.read(saveGoalsUseCaseProvider),
    ];

    for (int index = 0; index < signedOutDependencies.length; index++) {
      expect(
        authenticatedDependencies[index],
        isNot(same(signedOutDependencies[index])),
      );
    }
    expect(
      container.read(goalRepositoryProvider),
      same(authenticatedDependencies.first),
    );
  });

  test(
    'goals notifier reloads from the repository after an account change',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainGoalRepositoryProvider.overrideWith(
            (Ref ref) => ref.watch(_mutableGoalRepositoryProvider),
          ),
          reminderOrchestratorServiceProvider.overrideWithValue(
            ReminderOrchestratorService(
              preferences: _DisabledSharedPrefsStore(),
              notifications: NotificationsService(
                _NoopNotificationRepository(),
              ),
              scheduler: NotificationScheduler(),
              accountScope: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(goalsProvider).single.title, 'Account A goal');

      container.read(_mutableGoalRepositoryProvider.notifier).switchAccount();

      expect(container.read(goalsProvider).single.title, 'Account B goal');
    },
  );
}

final NotifierProvider<_MutableAccountStorageScopeNotifier, AccountStorageScope>
_mutableAccountStorageScopeProvider =
    NotifierProvider<_MutableAccountStorageScopeNotifier, AccountStorageScope>(
      _MutableAccountStorageScopeNotifier.new,
    );

class _MutableAccountStorageScopeNotifier
    extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void authenticate() {
    state = AccountStorageScope.authenticated('account-a');
  }
}

final NotifierProvider<_MutableGoalRepositoryNotifier, IGoalRepository>
_mutableGoalRepositoryProvider =
    NotifierProvider<_MutableGoalRepositoryNotifier, IGoalRepository>(
      _MutableGoalRepositoryNotifier.new,
    );

class _MutableGoalRepositoryNotifier extends Notifier<IGoalRepository> {
  @override
  IGoalRepository build() => _MemoryGoalRepository(
    GoalEntity(
      id: 'account-a-goal',
      title: 'Account A goal',
      createdAt: _goalCreatedAt,
    ),
  );

  void switchAccount() {
    state = _MemoryGoalRepository(
      GoalEntity(
        id: 'account-b-goal',
        title: 'Account B goal',
        createdAt: _goalCreatedAt,
      ),
    );
  }
}

final DateTime _goalCreatedAt = DateTime.utc(2026, 8, 31);

class _MemoryGoalRepository implements IGoalRepository {
  _MemoryGoalRepository(this.goal);

  final GoalEntity goal;

  @override
  List<GoalEntity> getGoals() => <GoalEntity>[goal];

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

class _DisabledSharedPrefsStore implements SharedPrefsStore {
  @override
  Future<void> init() async {}

  @override
  String? load(String key) => 'false';

  @override
  Future<void> save(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> clear() async {}
}

class _NoopNotificationRepository implements INotificationRepository {
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}

  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> delete(String id) async {}
}
