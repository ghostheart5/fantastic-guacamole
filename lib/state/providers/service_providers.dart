import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/services/workspace_store_service.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/services/cache_cleanup_service.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/expired_session_cleanup.dart';
import 'package:fantastic_guacamole/state/services/flowmap_service.dart';
import 'package:fantastic_guacamole/state/services/identity_service.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/orphan_data_cleanup.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';
import 'package:fantastic_guacamole/state/services/stale_notification_cleanup.dart';
import 'package:fantastic_guacamole/state/services/state_si_engine_service.dart';
import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final flowmapServiceProvider = Provider<FlowmapService>((Ref ref) {
  return FlowmapService(ref.read(flowmapRepositoryProvider));
});

final identityServiceProvider = Provider<IdentityServiceContract>((Ref ref) {
  if (Env.isMockMode || Env.isMockLoginEnabled) {
    return MockIdentityService(mockIdentity: 'mock-identity-0001');
  }
  return IdentityService(ref.read(identityRepositoryProvider));
});

final notificationsServiceProvider = Provider<NotificationsService>((Ref ref) {
  return NotificationsService(ref.read(notificationsRepositoryProvider));
});

final reminderOrchestratorServiceProvider = Provider<ReminderOrchestratorService>((Ref ref) {
  return ReminderOrchestratorService(
    preferences: ref.read(sharedPrefsStoreProvider),
    notifications: ref.read(notificationsServiceProvider),
    scheduler: ref.read(notificationSchedulerProvider),
  );
});

final siEngineDependenciesProvider = Provider<SiEngineDependencies>((Ref ref) {
  return SiEngineDependencies(
    tasks: ref.read(taskRepositoryProvider),
    goals: ref.read(goalRepositoryProvider),
    insights: ref.read(insightRepositoryProvider),
    flowmap: ref.read(flowmapRepositoryProvider),
    logs: ref.read(logRepositoryProvider),
    timeline: ref.read(timelineRepositoryProvider),
    progression: ref.read(progressionRepositoryProvider),
    memories: ref.read(memoryRepositoryProvider),
    plan: ref.read(planRepositoryProvider),
    notifications: ref.read(notificationsRepositoryProvider),
    profile: ref.read(profileRepositoryProvider),
  );
});

final siEngineServiceProvider = Provider<StateSiEngineService>((Ref ref) {
  return StateSiEngineService(
    ref.read(siEngineRepositoryProvider),
    dependencies: ref.read(siEngineDependenciesProvider),
  );
});

final workspaceStoreServiceProvider = Provider<WorkspaceStoreService>((Ref ref) {
  return WorkspaceStoreService(store: ref.read(secureStoreProvider));
});

final externalUrlServiceProvider = Provider<ExternalUrlService>((_) {
  return const ExternalUrlService();
});

final reflectionReminderServiceProvider = Provider<ReflectionReminderService>((Ref ref) {
  return ReflectionReminderService(
    preferences: ref.read(sharedPrefsStoreProvider),
    scheduler: ref.read(notificationSchedulerProvider),
  );
});

final voicePermissionServiceProvider = Provider<VoicePermissionService>((_) {
  return const VoicePermissionService();
});

final retentionPolicyProvider = Provider<RetentionPolicy>((_) {
  return RetentionPolicy.standard;
});

final cacheCleanupServiceProvider = Provider<CacheCleanupService>((Ref ref) {
  return CacheCleanupService(
    preferences: ref.read(sharedPrefsStoreProvider),
    hive: ref.read(hiveStoreProvider),
    secureStore: ref.read(secureStoreProvider),
  );
});

final orphanDataCleanupProvider = Provider<OrphanDataCleanup>((Ref ref) {
  return OrphanDataCleanup(
    preferences: ref.read(sharedPrefsStoreProvider),
    secureStore: ref.read(secureStoreProvider),
  );
});

final expiredSessionCleanupProvider = Provider<ExpiredSessionCleanup>((Ref ref) {
  return ExpiredSessionCleanup(
    secureStore: ref.read(secureStoreProvider),
    retentionPolicy: ref.read(retentionPolicyProvider),
  );
});

final staleNotificationCleanupProvider = Provider<StaleNotificationCleanup>((Ref ref) {
  return StaleNotificationCleanup(
    repository: ref.read(notificationsRepositoryProvider),
    retentionPolicy: ref.read(retentionPolicyProvider),
  );
});

final dataHygieneSchedulerProvider = Provider<DataHygieneScheduler>((Ref ref) {
  return DataHygieneScheduler(
    cacheCleanup: ref.read(cacheCleanupServiceProvider),
    orphanCleanup: ref.read(orphanDataCleanupProvider),
    expiredSessionCleanup: ref.read(expiredSessionCleanupProvider),
    staleNotificationCleanup: ref.read(staleNotificationCleanupProvider),
    retentionPolicy: ref.read(retentionPolicyProvider),
  );
});

final firebaseSupabaseBridgeProvider = Provider<void>((Ref ref) {
  final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
  final FirebaseSupabaseBridgeRepository bridgeRepository = ref.read(
    firebaseSupabaseBridgeRepositoryProvider,
  );

  Future<void> syncIfPossible({required String source}) async {
    final sb.SupabaseClient? activeClient = ref.read(supabaseClientProvider);
    if (activeClient == null) {
      return;
    }
    final String? token = FirebaseMessagingBootstrap.latestToken;
    if (token == null || token.trim().isEmpty) {
      return;
    }
    await bridgeRepository.syncFirebaseMessagingToken(activeClient, token, source: source);
  }

  if (client != null) {
    unawaited(syncIfPossible(source: 'bridge-bootstrap'));
  }

  ref.listen<AsyncValue<User?>>(authUserProvider, (_, next) {
    final User? user = next.asData?.value;
    if (user == null) {
      return;
    }
    unawaited(syncIfPossible(source: 'auth-state-change'));
  });
});
