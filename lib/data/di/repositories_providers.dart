// Package imports.
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/calendar_repository.dart';
import 'package:fantastic_guacamole/data/repositories/flowmap_repository.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/identity_repository.dart';
import 'package:fantastic_guacamole/data/repositories/insight_repository.dart';
import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart';
import 'package:fantastic_guacamole/data/repositories/plan_repository.dart';
import 'package:fantastic_guacamole/data/repositories/profile_repository.dart';
import 'package:fantastic_guacamole/data/repositories/progression_repository.dart';
import 'package:fantastic_guacamole/data/repositories/session_repository.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/repositories/theme_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/repositories/workspace_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

TaskRepository taskRepository(Ref ref) {
  return TaskRepository.secure(
    ref.read(secureStoreProvider),
    legacyStorage: HiveStorage<String>(HiveBoxes.tasks, hive: ref.read(hiveStoreProvider)),
  );
}

final taskRepositoryProvider = Provider<TaskRepository>(taskRepository);

final flowmapRepositoryProvider = Provider<FlowmapRepository>((Ref ref) {
  return FlowmapRepository.secure(
    ref.read(secureStoreProvider),
    legacyStorage: HiveStorage<String>(HiveBoxes.flowmap, hive: ref.read(hiveStoreProvider)),
  );
});

final goalRepositoryProvider = Provider<GoalRepository>((Ref ref) {
  return GoalRepository(ref.read(sensitivePrefsStoreProvider));
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
  return PlanRepository(ref.read(sharedPrefsStoreProvider));
});

final progressionRepositoryProvider = Provider<ProgressionRepository>((Ref ref) {
  return ProgressionRepository(ref.read(secureStoreProvider));
});

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (Ref ref) => NotificationScheduler(),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>((Ref ref) {
  return NotificationsRepository(
    ref.read(notificationSchedulerProvider),
    ref.read(secureStoreProvider),
  );
});

final appPaywallRepositoryProvider = Provider<IPaywallRepository>((Ref ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      secureStore: ref.read(secureStoreProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return PaywallRepository();
});

final siEngineRepositoryProvider = Provider<SiEngineRepository>((Ref ref) {
  return SiEngineRepository(ref.read(secureStoreProvider));
});

final logRepositoryProvider = Provider<LogRepository>((Ref ref) {
  return LogRepository(ref.read(secureStoreProvider));
});

final calendarRepositoryProvider = Provider<CalendarRepository>((Ref ref) {
  return CalendarRepository(ref.read(secureStoreProvider));
});

final timelineRepositoryProvider = Provider<TimelineRepository>((Ref ref) {
  return TimelineRepository(ref.read(sensitivePrefsStoreProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(ref.read(secureStoreProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  return SettingsRepository(ref.read(secureStoreProvider));
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
