// ============================================================
// CORE STORAGE
// ============================================================

import 'package:fantastic_guacamole/core/storage/hive_service.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/storage/storage_migration.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
// ============================================================
// CORE NETWORK + POLICIES
// ============================================================

import 'package:fantastic_guacamole/data/network/network_client.dart';
import 'package:fantastic_guacamole/data/policies/retry_policy.dart';
// ============================================================
// CORE LOGGING
// ============================================================

import 'package:fantastic_guacamole/data/repositories/log_repository.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/data/services/logs_service.dart';
import 'package:fantastic_guacamole/data/services/workspace_store_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
// ============================================================
// ============================================================
// FEATURE: FLOWMAP
// ============================================================

import 'package:fantastic_guacamole/features/flowmap/repositories/flowmap_repository.dart';
import 'package:fantastic_guacamole/features/flowmap/services/flowmap_service.dart';
// ============================================================
// FEATURE: IDENTITY
// ============================================================

import 'package:fantastic_guacamole/features/identity/repositories/identity_repository.dart';
import 'package:fantastic_guacamole/features/identity/services/identity_service.dart';
import 'package:fantastic_guacamole/features/logs/services/log_services.dart';
// ============================================================
// FEATURE: NOTIFICATIONS
// ============================================================

import 'package:fantastic_guacamole/features/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/features/notifications/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/features/notifications/services/notifications_service.dart';
import 'package:fantastic_guacamole/features/paywall/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/features/paywall/services/paywall_service.dart';
// ============================================================
// FEATURE: SETTINGS
// ============================================================

import 'package:fantastic_guacamole/features/settings/repositories/app_settings_repository.dart';
import 'package:fantastic_guacamole/features/settings/services/app_settings_service.dart';
// ============================================================
// FEATURE: SI ENGINE
// ============================================================

import 'package:fantastic_guacamole/features/si_engine/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/features/si_engine/services/si_engine_service.dart';
import 'package:fantastic_guacamole/features/tasks/repositories/task_repository.dart'
    as feature_tasks;
import 'package:fantastic_guacamole/features/tasks/services/task_service.dart';
// ============================================================
// FEATURE: TIMELINE
// ============================================================

import 'package:fantastic_guacamole/features/timeline/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/features/timeline/services/timeline_service.dart';
import 'package:fantastic_guacamole/state/intelligence/intelligence_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ============================================================
// CORE INITIALIZATION
// ============================================================

final appInitializerProvider = FutureProvider<void>((ref) async {
  await ref.read(hiveStoreProvider).init();
  await ref.read(sharedPrefsStoreProvider).init();
  await StorageMigration.run();
});

// ============================================================
// STORAGE PROVIDERS
// ============================================================

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  final intelligence = const IntelligenceService().environmentOnly();
  return SecureStore(
    backend: intelligence.flags.mockMode
        ? InMemorySecureStoreBackend()
        : RealSecureStoreBackend(
            storage: ref.read(flutterSecureStorageProvider),
          ),
  );
});
final hiveStoreProvider = Provider<HiveStore>((ref) {
  return const HiveStoreAdapter();
});
final sharedPrefsStoreProvider = Provider<SharedPrefsStore>((ref) {
  return const SharedPrefsStoreAdapter();
});

final supabaseClientProvider = Provider<sb.SupabaseClient>((ref) {
  return sb.Supabase.instance.client;
});

// ============================================================
// NETWORK + POLICY PROVIDERS
// ============================================================

final networkClientProvider = Provider<NetworkClientContract>((ref) {
  final intelligence = const IntelligenceService().environmentOnly();
  if (intelligence.flags.mockMode) {
    return const MockNetworkClient();
  }
  return NetworkClient();
});

final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  return const RetryPolicy(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 300),
    multiplier: 2.0,
    jitter: true,
  );
});

// ============================================================
// ============================================================
// FEATURE PROVIDERS
// ============================================================

// FLOWMAP
final flowmapRepositoryProvider = Provider<FlowmapRepository>((ref) {
  return FlowmapRepository(
    storage: HiveStorage<String>(
      'flowmap_box',
      hive: ref.read(hiveStoreProvider),
    ),
  );
});
final flowmapServiceProvider = Provider<FlowmapService>((ref) {
  return FlowmapService(ref.read(flowmapRepositoryProvider));
});

// IDENTITY
final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepository(ref.read(secureStoreProvider));
});
final identityServiceProvider = Provider<IdentityServiceContract>((ref) {
  final intelligence = const IntelligenceService().environmentOnly();
  if (intelligence.flags.mockMode) {
    return MockIdentityService(mockIdentity: 'mock-identity-0001');
  }
  return IdentityService(ref.read(identityRepositoryProvider));
});

// NOTIFICATIONS
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => NotificationScheduler(),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.read(notificationSchedulerProvider));
});
final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(ref.read(notificationsRepositoryProvider));
});

final paywallRepositoryProvider = Provider<IPaywallRepository>((ref) {
  return GooglePlayPaywallRepository();
});

final paywallServiceProvider = Provider<PaywallService>((ref) {
  return PaywallService(ref.read(paywallRepositoryProvider));
});

// SETTINGS
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(),
);
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService(ref.read(appSettingsRepositoryProvider));
});

// TIMELINE
final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => TimelineRepository(),
);
final timelineServiceProvider = Provider<TimelineService>((ref) {
  return TimelineService(ref.read(timelineRepositoryProvider));
});

// TASKS
final featureTaskRepositoryProvider = Provider<feature_tasks.TaskRepository>((
  ref,
) {
  return feature_tasks.TaskRepository(
    storage: HiveStorage<String>(
      'feature_tasks_box',
      hive: ref.read(hiveStoreProvider),
    ),
  );
});

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.read(featureTaskRepositoryProvider));
});

final agentOrchestratorProvider = Provider<AgentOrchestrator>((ref) {
  return const AgentOrchestrator();
});

// SI ENGINE
final siEngineRepositoryProvider = Provider<SiEngineRepository>((ref) {
  return SiEngineRepository(store: ref.read(secureStoreProvider));
});
final siEngineServiceProvider = Provider<SiEngineService>((ref) {
  return SiEngineService(ref.read(siEngineRepositoryProvider));
});

// ============================================================
// LOGGING
// ============================================================

final chronoLogsServiceProvider = Provider<ChronoLogsService>((ref) {
  return ChronoLogsService(store: ref.read(secureStoreProvider));
});

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(ref.read(chronoLogsServiceProvider));
});

final logServicesProvider = Provider<LogServices>((ref) {
  return const LogServices();
});

final workspaceStoreServiceProvider = Provider<WorkspaceStoreService>((ref) {
  return WorkspaceStoreService(store: ref.read(secureStoreProvider));
});
