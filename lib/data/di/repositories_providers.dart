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
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

TaskRepository taskRepository(Ref ref) {
  return TaskRepository(
    storage: HiveStorage<String>(
      HiveBoxes.tasks,
      hive: ref.read(hiveStoreProvider),
    ),
    syncDispatcher: ref.read(syncMutationDispatcherProvider),
  );
}

final taskRepositoryProvider = Provider<TaskRepository>(taskRepository);

final goalRepositoryProvider = Provider<GoalRepository>((Ref ref) {
  return GoalRepository(
    HiveStorage<String>(HiveBoxes.goals, hive: ref.read(hiveStoreProvider)),
    syncDispatcher: ref.read(syncMutationDispatcherProvider),
  );
});

final habitRepositoryProvider = Provider<HabitRepository>((Ref ref) {
  return HabitRepository(
    HiveStorage<String>(HiveBoxes.habits, hive: ref.read(hiveStoreProvider)),
    syncDispatcher: ref.read(syncMutationDispatcherProvider),
  );
});

final insightRepositoryProvider = Provider<InsightRepository>((Ref ref) {
  return InsightRepository(ref.read(sharedPrefsStoreProvider));
});

final identityRepositoryProvider = Provider<IdentityRepository>((Ref ref) {
  return IdentityRepository(ref.read(secureStoreProvider));
});

final memoryRepositoryProvider = Provider<MemoryRepository>((Ref ref) {
  return MemoryRepository(ref.read(sensitivePrefsStoreProvider));
});

final planRepositoryProvider = Provider<PlanRepository>((Ref ref) {
  return PlanRepository(
    HiveStorage<String>(
      HiveBoxes.dailyPlans,
      hive: ref.read(hiveStoreProvider),
    ),
  );
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
  return ProgressionRepository(
    HiveStorage<String>(
      HiveBoxes.progression,
      hive: ref.read(hiveStoreProvider),
    ),
  );
});

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (Ref ref) => NotificationScheduler(),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  Ref ref,
) {
  return NotificationsRepository(
    ref.read(notificationSchedulerProvider),
    ref.read(secureStoreProvider),
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
  return SiWorkspaceStore(ref.read(secureStoreProvider));
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
  return CompletionEventRepository(ref.read(sensitivePrefsStoreProvider));
});

final timelineRepositoryProvider = Provider<TimelineRepository>((Ref ref) {
  return TimelineRepository(ref.read(sensitivePrefsStoreProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(ref.read(secureStoreProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  return SettingsRepository(
    ref.read(sharedPrefsStoreProvider),
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
  return SyncQueueStore(
    HiveStorage<String>(
      HiveBoxes.offlineQueue,
      hive: ref.read(hiveStoreProvider),
    ),
  );
});

final syncMutationDispatcherProvider = Provider<SyncMutationDispatcher>((
  Ref ref,
) {
  return SyncMutationDispatcher(
    queueStore: ref.read(syncQueueStoreProvider),
    supabaseClient: ref.read(supabaseClientProvider),
    userId: ref.read(supabaseClientProvider)?.auth.currentUser?.id,
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
