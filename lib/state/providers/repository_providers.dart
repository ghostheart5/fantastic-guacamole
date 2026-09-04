// Package imports.
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/calendar_repository.dart';
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/identity_repository.dart';
import 'package:fantastic_guacamole/data/repositories/signal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/repositories/milestone_repository.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/plan_repository.dart';
import 'package:fantastic_guacamole/data/repositories/profile_repository.dart';
import 'package:fantastic_guacamole/data/repositories/progression_repository.dart';
import 'package:fantastic_guacamole/data/repositories/project_repository.dart';
import 'package:fantastic_guacamole/data/repositories/routine_repository.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/repositories/subtask_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/theme_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/repositories/workspace_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

TaskRepository taskRepository(Ref ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  return TaskRepository(
    storage: AccountScopedHiveStorage(
      baseBox: HiveBoxes.tasks,
      scope: scope,
      hive: ref.read(hiveStoreProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
    scope: scope,
  );
}

final taskRepositoryProvider = Provider<TaskRepository>(taskRepository);

final taskOccurrenceRepositoryProvider = Provider<TaskOccurrenceRepository>((
  Ref ref,
) {
  final scope = ref.watch(accountStorageScopeProvider);
  final TaskOccurrenceRepository repository = scope.isWritable
      ? TaskOccurrenceRepository(
          HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.taskOccurrences, scope),
            hive: ref.read(hiveStoreProvider),
          ),
        )
      : TaskOccurrenceRepository.unavailable();
  ref.onDispose(repository.dispose);
  return repository;
});

final goalRepositoryProvider = Provider<GoalRepository>((Ref ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  return GoalRepository(
    AccountScopedHiveStorage(
      baseBox: HiveBoxes.goals,
      scope: scope,
      hive: ref.read(hiveStoreProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
    scope: scope,
  );
});

final habitRepositoryProvider = Provider<HabitRepository>((Ref ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  return HabitRepository(
    AccountScopedHiveStorage(
      baseBox: HiveBoxes.habits,
      scope: scope,
      hive: ref.read(hiveStoreProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
    scope: scope,
  );
});

final signalRepositoryProvider = Provider<SignalRepository>((Ref ref) {
  return SignalRepository(
    _accountScopedPreferences(ref, ref.read(sharedPrefsStoreProvider)),
  );
});

final identityRepositoryProvider = Provider<IdentityRepository>((Ref ref) {
  return IdentityRepository(ref.watch(accountSecureStoreProvider));
});

final memoryRepositoryProvider = Provider<MemoryRepository>((Ref ref) {
  return MemoryRepository(
    ref.read(sensitivePrefsStoreProvider),
    ref.watch(accountStorageScopeProvider),
  );
});

final planRepositoryProvider = Provider<PlanRepository>((Ref ref) {
  return PlanRepository(_accountScopedHiveStorage(ref, HiveBoxes.dailyPlans));
});

final projectRepositoryProvider = Provider<ProjectRepository>((Ref ref) {
  return ProjectRepository(_accountScopedHiveStorage(ref, HiveBoxes.projects));
});

final routineRepositoryProvider = Provider<RoutineRepository>((Ref ref) {
  return RoutineRepository(_accountScopedHiveStorage(ref, HiveBoxes.routines));
});

final subtaskRepositoryProvider = Provider<SubtaskRepository>((Ref ref) {
  return SubtaskRepository(_accountScopedHiveStorage(ref, HiveBoxes.subtasks));
});

final progressionRepositoryProvider = Provider<ProgressionRepository>((
  Ref ref,
) {
  return ProgressionRepository(
    _accountScopedHiveStorage(ref, HiveBoxes.progression),
  );
});

AccountScopedHiveStorage _accountScopedHiveStorage(Ref ref, String baseBox) {
  final scope = ref.watch(accountStorageScopeProvider);
  return AccountScopedHiveStorage(
    baseBox: baseBox,
    scope: scope,
    hive: ref.read(hiveStoreProvider),
    legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
  );
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (Ref ref) => NotificationScheduler(),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  Ref ref,
) {
  final scope = ref.watch(accountStorageScopeProvider);
  return NotificationsRepository(
    ref.read(notificationSchedulerProvider),
    ref.read(secureStoreProvider),
    accountId: scope.isWritable ? scope.rawUserId : null,
  );
});

final appPaywallRepositoryProvider = Provider<IPaywallRepository>((Ref ref) {
  if (!Env.paidCreditPlansEnabled) {
    return const ContainedPaywallRepository();
  }
  final bool forceLocalTestingPaywall =
      Env.isMockLoginEnabled ||
      Env.isMockMode ||
      Env.isPaywallDisabled ||
      Env.hasTesterFullAccess;

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !forceLocalTestingPaywall) {
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      secureStore: ref.watch(accountSecureStoreProvider),
      supabaseClient: ref.watch(supabaseClientProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return PaywallRepository(testingModeOverride: forceLocalTestingPaywall);
});

final siEngineRepositoryProvider = Provider<SiEngineRepository>((Ref ref) {
  return SiEngineRepository(
    ref.read(secureStoreProvider),
    ref.watch(accountStorageScopeProvider),
  );
});

final logRepositoryProvider = Provider<LogRepository>((Ref ref) {
  return LogRepository(_accountScopedSecureStore(ref));
});

final calendarRepositoryProvider = Provider<CalendarRepository>((Ref ref) {
  return CalendarRepository(_accountScopedSecureStore(ref));
});

final timelineRepositoryProvider = Provider<TimelineRepository>((Ref ref) {
  return TimelineRepository(
    _accountScopedPreferences(ref, ref.read(sensitivePrefsStoreProvider)),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(_accountScopedSecureStore(ref));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  return SettingsRepository(ref.read(sharedPrefsStoreProvider));
});

final themeRepositoryProvider = Provider<ThemeRepository>((Ref ref) {
  return ThemeRepository(ref.read(sharedPrefsStoreProvider));
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((Ref ref) {
  return WorkspaceRepository(_accountScopedSecureStore(ref));
});

final firebaseSupabaseBridgeRepositoryProvider =
    Provider<FirebaseSupabaseBridgeRepository>((Ref ref) {
      return FirebaseSupabaseBridgeRepository(
        // The installation identity belongs to the physical app install, not
        // to whichever account is currently signed in. Server-side ownership
        // is claimed atomically by register_firebase_device().
        store: ref.watch(secureStoreProvider),
      );
    });
final noteRepositoryProvider = Provider<NoteRepository>(
  (Ref ref) => NoteRepository(
    ref.read(sharedPrefsStoreProvider),
    scope: ref.watch(accountStorageScopeProvider),
    legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
  ),
);

final milestoneRepositoryProvider = Provider<MilestoneRepository>(
  (Ref ref) => MilestoneRepository(_accountScopedSecureStore(ref)),
);

SecureStore _accountScopedSecureStore(Ref ref) {
  final scope = ref.watch(accountStorageScopeProvider);
  return ref
      .read(secureStoreProvider)
      .forAccount(
        scope,
        legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
      );
}

SharedPrefsStore _accountScopedPreferences(Ref ref, SharedPrefsStore delegate) {
  return AccountScopedSharedPrefsStore(
    delegate: delegate,
    scope: ref.watch(accountStorageScopeProvider),
    legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
  );
}
