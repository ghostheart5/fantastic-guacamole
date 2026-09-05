import 'dart:async';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/local_profile_auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;

import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const String _markerKey = 'auth_boundary_account_marker_v1';

void main() {
  if (Env.isLocalMode) {
    for (final bool deleteProfile in <bool>[true, false]) {
      test(
        'local ${deleteProfile ? 'profile deletion' : 'data clearing'} drains the departing outcome save before cleanup',
        () async {
          final store = _BlockingOutcomePreferences();
          final harness = _BoundaryHarness(
            useLocalAuth: true,
            liveOutcomeStore: store,
          );
          addTearDown(harness.dispose);
          harness.cleanup.onClear = (_) async => store.values.clear();
          await harness.coordinator.initialize();
          final local = harness.container.read(localProfileAuthServiceProvider);
          final user = await local.createProfile();
          await harness.settle();
          final repository = harness.container.read(
            decisionOutcomeRepositoryProvider,
          )!;
          final write = repository.record(
            DecisionOutcomeEntity(
              decisionId: 'pending-decision',
              kind: DecisionOutcomeKind.completed,
              surface: 'planner',
              recordedAt: DateTime.utc(2026, 9, 5),
              modelVersion: 'local',
              recommendationConfidence: 0.5,
            ),
          );
          await store.writeStarted.future;
          final Future<void> deletion = deleteProfile
              ? local.deleteCurrentAccount(password: '').then<void>((_) {})
              : harness.coordinator.clearLocalDataForCurrentAccount(user.id);
          addTearDown(() async {
            if (!store.releaseWrite.isCompleted) store.releaseWrite.complete();
            await write;
            await deletion;
          });
          await harness.settle();
          expect(
            harness.container.read(accountStorageScopeProvider).isWritable,
            isFalse,
          );
          expect(
            harness.cleanup.clearCalls,
            0,
            reason: 'Cleanup must wait for the departing repository save.',
          );
          store.releaseWrite.complete();
          await write;
          await deletion;
          await harness.settle();
          expect(harness.cleanup.clearCalls, 1);
          expect(local.hasStoredProfile, !deleteProfile);
          expect(
            harness.container.read(accountStorageScopeProvider).isWritable,
            !deleteProfile,
          );
          expect(
            store.values,
            isEmpty,
            reason:
                'A late outcome write must not recreate deleted profile data.',
          );
        },
      );
    }

    test(
      'provider identity grants local routing only after isolation and deletion closes scope',
      () async {
        final harness = _BoundaryHarness(useLocalAuth: true);
        addTearDown(harness.dispose);
        final local = harness.container.read(localProfileAuthServiceProvider);
        final initialized = harness.coordinator.initialize();
        await initialized;
        expect(
          harness.container.read(guards.authenticatedGuardProvider),
          isFalse,
        );
        final user = await local.createProfile();
        await harness.settle();
        expect(harness.container.read(authServiceProvider), same(local));
        expect(
          harness.container.read(guards.authenticatedGuardProvider),
          isTrue,
        );
        expect(
          harness.container.read(accountStorageScopeProvider).rawUserId,
          user.id,
        );
        expect(
          harness.boundary.legacyOwnership,
          LegacyScopeOwnership.provenNotOwned,
        );
        await local.deleteCurrentAccount(password: '');
        await harness.settle();
        expect(harness.cleanup.clearedAccountId, user.id);
        expect(
          harness.container.read(accountStorageScopeProvider).isWritable,
          isFalse,
        );
        expect(
          harness.container.read(guards.authenticatedGuardProvider),
          isFalse,
        );
        expect(local.hasStoredProfile, isFalse);
      },
    );

    test(
      'local profile opens its own namespace without claiming markerless legacy data',
      () async {
        final harness = _BoundaryHarness(hasUnownedData: true);
        addTearDown(harness.dispose);
        final initialized = harness.coordinator.initialize();
        harness.auth.add(
          const User.localProfile(id: 'local-00000000000000000000000000000001'),
        );
        await initialized;
        expect(harness.boundary.isStorageReady, isTrue);
        expect(
          harness.boundary.legacyOwnership,
          LegacyScopeOwnership.provenNotOwned,
        );
        expect(await harness.secureStore.readString(_markerKey), isNull);
        expect(harness.cleanup.clearCalls, 0);
      },
    );

    test('local profile preserves a cloud legacy owner marker', () async {
      final harness = _BoundaryHarness(hasUnownedData: true);
      addTearDown(harness.dispose);
      await harness.secureStore.writeString(_markerKey, 'cloud-account');
      final initialized = harness.coordinator.initialize();
      harness.auth.add(
        const User.localProfile(id: 'local-00000000000000000000000000000002'),
      );
      await initialized;
      expect(harness.boundary.isStorageReady, isTrue);
      expect(
        harness.boundary.legacyOwnership,
        LegacyScopeOwnership.provenNotOwned,
      );
      expect(await harness.secureStore.readString(_markerKey), 'cloud-account');
      expect(harness.cleanup.clearCalls, 0);
    });
  }
  test(
    'first verified account claims an empty device and opens storage',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness(hasUnownedData: false);
      addTearDown(harness.dispose);

      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.add(_user('account-a'));
      await initialized;

      final AuthSessionBoundary boundary = harness.boundary;
      expect(boundary.userId, 'account-a');
      expect(boundary.isTransitioning, isFalse);
      expect(boundary.isStorageReady, isTrue);
      expect(boundary.blockingIssue, isNull);
      expect(await harness.secureStore.readString(_markerKey), 'account-a');

      expect(harness.coordinator.initialize(), same(initialized));
      harness.auth.add(_user('account-a'));
      await harness.settle();
      expect(harness.boundary.generation, 1);
    },
  );

  test('sign-out closes storage without deleting preserved data', () async {
    final _BoundaryHarness harness = _BoundaryHarness();
    addTearDown(harness.dispose);
    final Future<void> initialized = harness.coordinator.initialize();
    harness.auth.add(null);
    await initialized;

    expect(harness.boundary.userId, isNull);
    expect(harness.boundary.isTransitioning, isFalse);
    expect(harness.boundary.isStorageReady, isFalse);
    expect(harness.cleanup.clearCalls, 0);
  });

  test(
    'different account opens only its V2 scope while legacy owner is preserved',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness();
      addTearDown(harness.dispose);
      await harness.secureStore.writeString(_markerKey, 'account-a');
      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.add(_user('account-b'));
      await initialized;

      expect(harness.boundary.userId, 'account-b');
      expect(harness.boundary.isStorageReady, isTrue);
      expect(harness.boundary.blockingIssue, isNull);
      expect(
        harness.boundary.legacyOwnership,
        LegacyScopeOwnership.provenNotOwned,
      );
      expect(await harness.secureStore.readString(_markerKey), 'account-a');
    },
  );

  test(
    'A to B to A keeps the stable legacy owner and rotates access',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness();
      addTearDown(harness.dispose);
      await harness.secureStore.writeString(_markerKey, 'account-a');
      final Future<void> initialized = harness.coordinator.initialize();

      harness.auth.add(_user('account-a'));
      await initialized;
      expect(harness.boundary.isStorageReady, isTrue);
      expect(
        harness.boundary.legacyOwnership,
        LegacyScopeOwnership.provenOwned,
      );

      harness.auth.add(null);
      await harness.settle();
      expect(harness.boundary.isStorageReady, isFalse);
      expect(await harness.secureStore.readString(_markerKey), 'account-a');

      harness.auth.add(_user('account-b'));
      await harness.settle();
      expect(harness.boundary.userId, 'account-b');
      expect(harness.boundary.isStorageReady, isTrue);
      expect(
        harness.boundary.legacyOwnership,
        LegacyScopeOwnership.provenNotOwned,
      );
      expect(await harness.secureStore.readString(_markerKey), 'account-a');

      harness.auth.add(null);
      await harness.settle();
      harness.auth.add(_user('account-a'));
      await harness.settle();
      expect(harness.boundary.userId, 'account-a');
      expect(harness.boundary.isStorageReady, isTrue);
      expect(
        harness.boundary.legacyOwnership,
        LegacyScopeOwnership.provenOwned,
      );
      expect(await harness.secureStore.readString(_markerKey), 'account-a');
      expect(harness.cleanup.clearCalls, 0);
    },
  );

  test(
    'markerless data is blocked until the user explicitly claims it',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness(hasUnownedData: true);
      addTearDown(harness.dispose);
      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.add(_user('account-a'));
      await initialized;

      expect(harness.boundary.canClaimPreservedData, isTrue);
      expect(harness.boundary.canClearPreservedData, isTrue);
      expect(harness.boundary.isStorageReady, isFalse);

      await harness.coordinator.claimPreservedDataForCurrentAccount();
      expect(harness.boundary.isStorageReady, isTrue);
      expect(harness.boundary.isTransitioning, isFalse);
      expect(await harness.secureStore.readString(_markerKey), 'account-a');
      expect(harness.cleanup.clearCalls, 0);
    },
  );

  test(
    'explicit clear removes preserved data before opening the gate',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness(hasUnownedData: true);
      addTearDown(harness.dispose);
      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.add(_user('account-a'));
      await initialized;

      await harness.coordinator.clearPreservedDataForCurrentAccount();
      expect(harness.cleanup.clearCalls, 1);
      expect(harness.boundary.isStorageReady, isTrue);
      expect(await harness.secureStore.readString(_markerKey), 'account-a');
    },
  );

  test(
    'invalid recovery calls are no-ops and auth errors fail closed',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness();
      addTearDown(harness.dispose);
      await harness.coordinator.claimPreservedDataForCurrentAccount();
      await harness.coordinator.clearPreservedDataForCurrentAccount();
      expect(harness.cleanup.clearCalls, 0);

      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.addError(StateError('auth unavailable'));
      await initialized;
      expect(harness.boundary.blockingIssue, contains('could not be verified'));
      expect(harness.boundary.canRecoverBySigningOut, isTrue);
      expect(harness.boundary.canClearPreservedData, isFalse);
    },
  );

  test(
    'secure-store failure blocks storage and dispose completes initialization',
    () async {
      final _BoundaryHarness failing = _BoundaryHarness(
        secureStore: SecureStore(backend: _FailingSecureStoreBackend()),
      );
      addTearDown(failing.dispose);
      final Future<void> initialized = failing.coordinator.initialize();
      failing.auth.add(_user('account-a'));
      await initialized.timeout(const Duration(seconds: 3));
      expect(failing.boundary.blockingIssue, contains('could not isolate'));
      expect(failing.boundary.isStorageReady, isFalse);

      final _BoundaryHarness disposed = _BoundaryHarness();
      final Future<void> pending = disposed.coordinator.initialize();
      disposed.coordinator.dispose();
      await pending.timeout(const Duration(seconds: 3));
      await disposed.dispose();
    },
  );

  test(
    'explicit local clear requires and forwards the current authenticated account',
    () async {
      final _BoundaryHarness harness = _BoundaryHarness();
      addTearDown(harness.dispose);
      await harness.secureStore.writeString(_markerKey, 'account-a');
      final Future<void> initialized = harness.coordinator.initialize();
      harness.auth.add(_user('account-a'));
      await initialized;

      await expectLater(
        harness.coordinator.clearLocalDataForCurrentAccount('account-b'),
        throwsStateError,
      );
      expect(harness.cleanup.clearCalls, 0);

      await harness.coordinator.clearLocalDataForCurrentAccount('account-a');

      expect(harness.cleanup.clearCalls, 1);
      expect(harness.cleanup.clearedAccountId, 'account-a');
      expect(harness.boundary.userId, 'account-a');
      expect(harness.boundary.isStorageReady, isTrue);
      expect(harness.boundary.isTransitioning, isFalse);
    },
  );

  test('only the proven legacy owner receives reminder migration', () async {
    final _BoundaryHarness harness = _BoundaryHarness();
    addTearDown(harness.dispose);
    await harness.secureStore.writeString(_markerKey, 'account-a');
    await harness.preferences.save('goal_reminders_enabled', 'false');
    final Future<void> initialized = harness.coordinator.initialize();
    harness.auth.add(_user('account-a'));
    await initialized;

    final String namespaceA = AccountDataRegistry.accountNamespace('account-a');
    expect(
      harness.preferences.load('goal_reminders_enabled.$namespaceA'),
      'false',
    );

    harness.auth.add(null);
    await harness.settle();
    harness.auth.add(_user('account-b'));
    await harness.settle();
    final String namespaceB = AccountDataRegistry.accountNamespace('account-b');
    expect(
      harness.preferences.load('goal_reminders_enabled.$namespaceB'),
      isNull,
    );
    expect(harness.preferences.load('goal_reminders_enabled'), 'false');
  });
}

User _user(String id) => User(id: id, emailVerified: true);

final class _BoundaryHarness {
  _BoundaryHarness({
    bool hasUnownedData = false,
    SecureStore? secureStore,
    bool useLocalAuth = false,
    SharedPrefsStore? liveOutcomeStore,
  }) : auth = StreamController<User?>.broadcast(),
       secureStore =
           secureStore ?? SecureStore(backend: InMemorySecureStoreBackend()),
       cleanup = _TestCleanupService(hasUnownedData: hasUnownedData) {
    final AccountStorageScope coordinatorScope =
        AccountStorageScope.authenticated('coordinator-account');
    final _MemoryPreferences outcomePreferences = _MemoryPreferences();
    final TaskOccurrenceCoordinator occurrenceCoordinator =
        TaskOccurrenceCoordinator(
          scope: coordinatorScope,
          taskRepository: _EmptyTaskRepository(),
          occurrenceRepository: TaskOccurrenceRepository.unavailable(),
        );
    final DecisionOutcomeRepository outcomeRepository =
        DecisionOutcomeRepository(outcomePreferences, coordinatorScope);
    container = ProviderContainer(
      overrides: [
        if (!useLocalAuth)
          authUserProvider.overrideWith((Ref ref) => auth.stream),
        if (useLocalAuth)
          supabaseClientProvider.overrideWith(
            (Ref ref) => throw StateError('Local auth must not read Supabase.'),
          ),
        secureStoreProvider.overrideWithValue(this.secureStore),
        localUserDataCleanupServiceProvider.overrideWithValue(cleanup),
        taskOccurrenceCoordinatorProvider.overrideWithValue(
          occurrenceCoordinator,
        ),
        if (liveOutcomeStore == null)
          decisionOutcomeRepositoryProvider.overrideWithValue(outcomeRepository)
        else
          decisionOutcomeRepositoryProvider.overrideWith((ref) {
            final scope = ref.watch(accountStorageScopeProvider);
            return scope.isWritable
                ? DecisionOutcomeRepository(liveOutcomeStore, scope)
                : null;
          }),
        sharedPrefsStoreProvider.overrideWithValue(preferences),
        domainTaskRepositoryProvider.overrideWithValue(_EmptyTaskRepository()),
      ],
    );
  }

  final StreamController<User?> auth;
  final SecureStore secureStore;
  final _TestCleanupService cleanup;
  final _MemoryPreferences preferences = _MemoryPreferences();
  late final ProviderContainer container;

  AuthSessionBoundaryCoordinator get coordinator =>
      container.read(authSessionBoundaryCoordinatorProvider);

  AuthSessionBoundary get boundary =>
      container.read(authSessionBoundaryProvider);

  Future<void> settle() async {
    for (int index = 0; index < 6; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    container.dispose();
    await auth.close();
  }
}

final class _EmptyTaskRepository implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

final class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}

final class _TestCleanupService extends LocalUserDataCleanupService {
  _TestCleanupService({required this.hasUnownedData})
    : super(
        hive: _UnusedHiveStore(),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        preferences: _MemoryPreferences(),
        sensitivePreferences: _MemoryPreferences(),
        notifications: NotificationScheduler(),
      );

  final bool hasUnownedData;
  int clearCalls = 0;
  String? clearedAccountId;
  Future<void> Function(String)? onClear;

  @override
  Future<void> clearForAccountSwitch(String accountId) async {
    clearCalls += 1;
    clearedAccountId = accountId;
    await onClear?.call(accountId);
  }

  @override
  Future<void> clearUnownedLegacyData() async {
    clearCalls += 1;
  }

  @override
  Future<bool> hasUnownedAccountData() async => hasUnownedData;
}

final class _UnusedHiveStore implements HiveStore {
  Never _unused() => throw UnsupportedError('Unused by boundary test double');

  @override
  Box<T> box<T>(String key) => _unused();

  @override
  Future<void> clearBox(String key) async => _unused();

  @override
  Future<void> closeBox(String key) async => _unused();

  @override
  Future<void> init() async => _unused();

  @override
  bool isBoxOpen(String key) => _unused();

  @override
  Future<Box<T>> openBox<T>(String key) async => _unused();
}

final class _FailingSecureStoreBackend implements SecureStoreBackend {
  StateError _failure() => StateError('secure store unavailable');

  @override
  Future<void> delete({required String key}) async => throw _failure();

  @override
  Future<void> deleteAll() async => throw _failure();

  @override
  Future<String?> read({required String key}) async => throw _failure();

  @override
  Future<Map<String, String>> readAll() async => throw _failure();

  @override
  Future<void> write({required String key, required String value}) async =>
      throw _failure();
}

final class _BlockingOutcomePreferences implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> releaseWrite = Completer<void>();
  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await releaseWrite.future;
    values[key] = value;
  }
}
