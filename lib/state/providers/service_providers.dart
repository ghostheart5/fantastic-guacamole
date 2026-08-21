import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/services/workspace_store_service.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/services/cache_cleanup_service.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/expired_session_cleanup.dart';
import 'package:fantastic_guacamole/state/services/identity_service.dart';
import 'package:fantastic_guacamole/state/services/local_user_data_cleanup_service.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

bool get _supportsCrashlytics =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

final identityServiceProvider = Provider<IdentityServiceContract>((Ref ref) {
  if (Env.isMockMode || Env.isMockLoginEnabled) {
    return MockIdentityService(mockIdentity: 'mock-identity-0001');
  }
  return IdentityService(ref.read(identityRepositoryProvider));
});

final notificationsServiceProvider = Provider<NotificationsService>((Ref ref) {
  return NotificationsService(ref.read(notificationsRepositoryProvider));
});

final localUserDataCleanupServiceProvider =
    Provider<LocalUserDataCleanupService>((Ref ref) {
      return LocalUserDataCleanupService(
        hive: ref.read(hiveStoreProvider),
        secureStore: ref.read(secureStoreProvider),
        preferences: ref.read(sharedPrefsStoreProvider),
        sensitivePreferences: ref.read(sensitivePrefsStoreProvider),
        notifications: ref.read(notificationSchedulerProvider),
      );
    });

final reminderOrchestratorServiceProvider =
    Provider<ReminderOrchestratorService>((Ref ref) {
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
    signals: ref.read(signalRepositoryProvider),
    logs: ref.read(logRepositoryProvider),
    timeline: ref.read(timelineRepositoryProvider),
    progression: ref.read(progressionRepositoryProvider),
    memories: ref.watch(memoryRepositoryProvider),
    plan: ref.read(planRepositoryProvider),
    notifications: ref.read(notificationsRepositoryProvider),
    profile: ref.read(profileRepositoryProvider),
  );
});

final siEngineServiceProvider = Provider<StateSiEngineService>((Ref ref) {
  return StateSiEngineService(
    ref.watch(siEngineRepositoryProvider),
    dependencies: ref.watch(siEngineDependenciesProvider),
  );
});

final workspaceStoreServiceProvider = Provider<WorkspaceStoreService>((
  Ref ref,
) {
  return WorkspaceStoreService(store: ref.read(secureStoreProvider));
});

final externalUrlServiceProvider = Provider<ExternalUrlService>((_) {
  return const ExternalUrlService();
});

final reflectionReminderServiceProvider = Provider<ReflectionReminderService>((
  Ref ref,
) {
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

final expiredSessionCleanupProvider = Provider<ExpiredSessionCleanup>((
  Ref ref,
) {
  return ExpiredSessionCleanup(
    secureStore: ref.read(secureStoreProvider),
    retentionPolicy: ref.read(retentionPolicyProvider),
  );
});

final staleNotificationCleanupProvider = Provider<StaleNotificationCleanup>((
  Ref ref,
) {
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
    try {
      final sb.SupabaseClient? activeClient = ref.read(supabaseClientProvider);
      if (activeClient == null) {
        return;
      }
      final String? token = FirebaseMessagingBootstrap.latestToken;
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await bridgeRepository.syncFirebaseMessagingToken(
        activeClient,
        token,
        source: source,
      );
    } on Exception catch (error) {
      Logger.warn(
        'Firebase->Supabase bridge sync skipped non-fatally (source=$source): $error',
      );
    }
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

  // Crashes today are anonymous; tying them to the signed-in user (cleared on
  // sign-out) is the only place this is wired in the whole app.
  ref.listen<AsyncValue<User?>>(authUserProvider, (_, next) {
    if (next is! AsyncData<User?>) {
      return;
    }
    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      unawaited(
        FirebaseCrashlytics.instance.setUserIdentifier(
          crashlyticsUserId(next.value),
        ),
      );
    }
  });
});

/// Pure derivation of the id Crashlytics should tag a crash report with —
/// the signed-in user's id, or `''` once signed out. Extracted so it's
/// directly unit-testable without touching the real Crashlytics plugin.
@visibleForTesting
String crashlyticsUserId(User? user) => user?.id ?? '';
