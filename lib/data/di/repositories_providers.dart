// Package imports.
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/remote/goals_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habits_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/settings_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/tasks_remote_gateway.dart';
import 'package:fantastic_guacamole/data/repositories/calendar_repository.dart';
import 'package:fantastic_guacamole/data/repositories/completion_event_repository.dart';
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/identity_repository.dart';
import 'package:fantastic_guacamole/data/repositories/insight_repository.dart';
import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/plan_repository.dart';
import 'package:fantastic_guacamole/data/repositories/profile_repository.dart';
import 'package:fantastic_guacamole/data/repositories/progression_repository.dart';
import 'package:fantastic_guacamole/data/repositories/project_repository.dart';
import 'package:fantastic_guacamole/data/repositories/routine_repository.dart';
import 'package:fantastic_guacamole/data/repositories/session_repository.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/repositories/subtask_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/repositories/theme_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/repositories/workspace_repository.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/si_workspace_store.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

TaskRepository taskRepository(Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final TaskRepository repository = scope.v2Namespace == null
      ? TaskRepository.unavailable(
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        )
      : TaskRepository(
          storage: HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.tasks, scope),
            hive: ref.read(hiveStoreProvider),
          ),
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        );
  ref.onDispose(repository.dispose);
  return repository;
}

final taskRepositoryProvider = Provider<TaskRepository>(taskRepository);

final goalRepositoryProvider = Provider<GoalRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final GoalRepository repository = scope.v2Namespace == null
      ? GoalRepository.unavailable(
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        )
      : GoalRepository(
          HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.goals, scope),
            hive: ref.read(hiveStoreProvider),
          ),
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        );
  ref.onDispose(repository.dispose);
  return repository;
});

final habitRepositoryProvider = Provider<HabitRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final HabitRepository repository = scope.v2Namespace == null
      ? HabitRepository.unavailable(
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        )
      : HabitRepository(
          HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.habits, scope),
            hive: ref.read(hiveStoreProvider),
          ),
          syncDispatcher: ref.read(syncMutationDispatcherProvider),
        );
  ref.onDispose(repository.dispose);
  return repository;
});

final insightRepositoryProvider = Provider<InsightRepository>((Ref ref) {
  return InsightRepository(ref.read(sharedPrefsStoreProvider));
});

final identityRepositoryProvider = Provider<IdentityRepository>((Ref ref) {
  return IdentityRepository(ref.read(secureStoreProvider));
});

final memoryRepositoryProvider = Provider<MemoryRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  return MemoryRepository(
    ref.read(sensitivePrefsStoreProvider),
    storageScope: scope,
  );
});

final planRepositoryProvider = Provider<PlanRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final PlanRepository repository = scope.v2Namespace == null
      ? PlanRepository.unavailable()
      : PlanRepository(
          HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.dailyPlans, scope),
            hive: ref.read(hiveStoreProvider),
          ),
        );
  ref.onDispose(repository.dispose);
  return repository;
});

final projectRepositoryProvider = Provider<ProjectRepository>((Ref ref) {
  return ProjectRepository(
    HiveStorage<String>(HiveBoxes.projects, hive: ref.read(hiveStoreProvider)),
  );
});

final routineRepositoryProvider = Provider<RoutineRepository>((Ref ref) {
  return RoutineRepository(
    HiveStorage<String>(HiveBoxes.routines, hive: ref.read(hiveStoreProvider)),
  );
});

final subtaskRepositoryProvider = Provider<SubtaskRepository>((Ref ref) {
  return SubtaskRepository(
    HiveStorage<String>(HiveBoxes.subtasks, hive: ref.read(hiveStoreProvider)),
  );
});

final progressionRepositoryProvider = Provider<ProgressionRepository>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  return ProgressionRepository(
    readCurrent: () async {
      if (!_isCurrentAuthenticatedScope(ref, scope)) return null;
      final ProfileState state = ref.read(profileProvider);
      return ProgressionEntity(
        xp: state.xp,
        level: state.level,
        streak: state.streak,
      );
    },
    writeCurrent: (ProgressionEntity progression) async {
      _requireCurrentAuthenticatedScope(ref, scope);
      await ref.read(profileProvider.notifier).setProgressionSnapshot(
        xp: progression.xp,
        level: progression.level,
        streak: progression.streak,
      );
    },
  );
});

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (Ref ref) => NotificationScheduler(),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  return NotificationsRepository(
    ref.read(notificationSchedulerProvider),
    ref.read(secureStoreProvider),
    storageScope: scope,
  );
});

final appPaywallRepositoryProvider = Provider<IPaywallRepository>((Ref ref) {
  final bool forceLocalTestingPaywall =
      Env.isMockLoginEnabled ||
      Env.isMockMode ||
      Env.isPaywallDisabled ||
      Env.hasTesterFullAccess;

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !forceLocalTestingPaywall) {
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      secureStore: ref.read(secureStoreProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return PaywallRepository(testingModeOverride: forceLocalTestingPaywall);
});

final siEngineRepositoryProvider = Provider<ISiRepository>((Ref ref) {
  return SiEngineRepository(ref.read(secureStoreProvider));
});

final siWorkspaceStoreProvider = Provider<SiWorkspaceStore>((Ref ref) {
  return SiWorkspaceStore(
    ref.read(secureStoreProvider),
    storageScope: ref.watch(accountStorageScopeProvider),
  );
});

final logRepositoryProvider = Provider<LogRepository>((Ref ref) {
  return LogRepository(ref.read(secureStoreProvider));
});

final calendarRepositoryProvider = Provider<CalendarRepository>((Ref ref) {
  return CalendarRepository(ref.read(secureStoreProvider));
});

final completionEventRepositoryProvider = Provider<CompletionEventRepository>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final store = ref.read(sensitivePrefsStoreProvider);
  return scope.v2Namespace == null
      ? CompletionEventRepository.unavailable(store)
      : CompletionEventRepository(store, scope);
});

final timelineRepositoryProvider = Provider<TimelineRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final store = ref.read(sensitivePrefsStoreProvider);
  return scope.v2Namespace == null
      ? TimelineRepository.unavailable(store)
      : TimelineRepository(store, scope);
});

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  return ProfileRepository(
    readCurrent: () async {
      if (!_isCurrentAuthenticatedScope(ref, scope)) return null;
      return _profileEntityFromState(ref.read(profileProvider));
    },
    writeCurrent: (ProfileEntity profile) async {
      _requireCurrentAuthenticatedScope(ref, scope);
      await ref
          .read(profileProvider.notifier)
          .applyCanonicalSnapshot(_snapshotFromProfileEntity(profile));
    },
  );
});

bool _isCurrentAuthenticatedScope(Ref ref, AccountStorageScope expected) {
  final AccountStorageScope current = ref.read(accountStorageScopeProvider);
  return expected.isAuthenticated &&
      expected.v2Namespace != null &&
      current.v2Namespace == expected.v2Namespace;
}

void _requireCurrentAuthenticatedScope(
  Ref ref,
  AccountStorageScope expected,
) {
  if (!_isCurrentAuthenticatedScope(ref, expected)) {
    throw StateError('Profile authority is unavailable for the retained scope.');
  }
}

ProfileEntity _profileEntityFromState(ProfileState state) => ProfileEntity(
  xp: state.xp,
  level: state.level,
  legacyLevelFloor: state.legacyLevelFloor,
  streak: state.streak,
  longestStreak: state.longestStreak,
  name: state.name,
  lastActiveDate: state.lastActiveDate,
  profileReady: state.profileReady,
);

ProfileCanonicalSnapshot _snapshotFromProfileEntity(ProfileEntity profile) =>
    ProfileCanonicalSnapshot(
      xp: profile.xp,
      legacyLevelFloor: profile.level > profile.legacyLevelFloor
          ? profile.level
          : profile.legacyLevelFloor,
      streak: profile.streak,
      longestStreak: profile.longestStreak,
      name: profile.name,
      lastActiveDate: profile.lastActiveDate,
      profileReady: profile.profileReady,
    );

final settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  return SettingsRepository(
    ref.read(sharedPrefsStoreProvider),
    storageScope: scope,
    syncDispatcher: ref.read(syncMutationDispatcherProvider),
  );
});

final themeRepositoryProvider = Provider<ThemeRepository>((Ref ref) {
  return ThemeRepository(ref.read(sharedPrefsStoreProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((Ref ref) {
  return SessionRepository(ref.read(secureStoreProvider));
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((Ref ref) {
  return WorkspaceRepository(ref.read(secureStoreProvider));
});

final firebaseSupabaseBridgeRepositoryProvider =
    Provider<FirebaseSupabaseBridgeRepository>((Ref ref) {
      return FirebaseSupabaseBridgeRepository(
        store: ref.read(secureStoreProvider),
      );
    });

final syncQueueStoreProvider = Provider<SyncQueueStore>((Ref ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isAuthenticated || scope.v2Namespace == null) {
    return SyncQueueStore.unavailable();
  }
  return SyncQueueStore(
    HiveStorage<String>(
      HiveBoxes.accountScoped(HiveBoxes.offlineQueue, scope),
      hive: ref.read(hiveStoreProvider),
    ),
    storageScope: scope,
  );
});

final syncMutationDispatcherProvider = Provider<SyncMutationDispatcher>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  bool leaseActive = true;
  ref.onDispose(() => leaseActive = false);
  return SyncMutationDispatcher(
    queueStore: ref.watch(syncQueueStoreProvider),
    supabaseClient: ref.watch(supabaseClientProvider),
    userId: scope.isAuthenticated ? scope.rawUserId : null,
    isAuthorized: () => leaseActive,
  );
});

final tasksRemoteGatewayProvider = Provider<TasksRemoteGateway>((Ref ref) {
  return TasksRemoteGateway(ref.read(supabaseClientProvider));
});

final goalsRemoteGatewayProvider = Provider<GoalsRemoteGateway>((Ref ref) {
  return GoalsRemoteGateway(ref.read(supabaseClientProvider));
});

final habitsRemoteGatewayProvider = Provider<HabitsRemoteGateway>((Ref ref) {
  return HabitsRemoteGateway(ref.read(supabaseClientProvider));
});

final settingsRemoteGatewayProvider = Provider<SettingsRemoteGateway>((
  Ref ref,
) {
  return SettingsRemoteGateway(ref.read(supabaseClientProvider));
});
