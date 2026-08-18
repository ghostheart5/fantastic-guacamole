import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-safe sync failure state. Raw exceptions remain in the redacted logger
/// and are never rendered by Nexus or settings surfaces.
final syncErrorMessageProvider =
    NotifierProvider<SyncErrorMessageNotifier, String?>(
      SyncErrorMessageNotifier.new,
    );

class SyncErrorMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void clear() => state = null;
  void report(String message) => state = message;
}

final _sharedPrefsProvider = FutureProvider<SharedPrefsStorage>((ref) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return SharedPrefsStorage(prefs);
});

final _backupServiceProvider = Provider<BackupService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => BackupService(
      taskRepository: ref.read(domainTaskRepositoryProvider),
      profileStorage: HiveStorage<String>(
        'profile_box',
        hive: const HiveStoreAdapter(),
      ),
      prefs: prefs,
      secureProfileStore: ref.read(secureStoreProvider),
    ),
  );
});

/// Build-time capability gate kept injectable so command behavior can be
/// verified without changing production environment variables.
final cloudSyncCapabilityProvider = Provider<bool>(
  (Ref ref) => Env.enableCloudSync,
);

/// Account-bound production queue. Tests and alternate local runtimes may
/// inject an isolated queue while preserving the same replay semantics.
final offlineSyncQueueProvider = Provider<OfflineSyncQueueService?>((ref) {
  final HiveStore hive = ref.read(hiveStoreProvider);
  final client = ref.read(supabaseClientProvider);
  return OfflineSyncQueueService(
    HiveStorage<String>(HiveBoxes.offlineQueue, hive: hive),
    accountId: client?.auth.currentUser?.id,
    enforceAccountBinding: true,
  );
});

OfflineSyncQueueService? _boundQueue(Ref ref) {
  final OfflineSyncQueueService? queue = ref.read(offlineSyncQueueProvider);
  final client = ref.read(supabaseClientProvider);
  queue?.rebind(client?.auth.currentUser?.id);
  return queue;
}

final syncServiceProvider = Provider<SyncService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  final BackupService? backup = ref.watch(_backupServiceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final bool userEnabled =
      ref.watch(cloudSyncPreferenceProvider).asData?.value ?? false;
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => backup == null
        ? null
        : SyncService(
            backup: backup,
            gateway: Env.isMockMode
                ? LocalTestCloudBackupGateway(prefs)
                : (Env.enableCloudSync && userEnabled && supabaseClient != null)
                ? SupabaseStorageCloudBackupGateway(client: supabaseClient)
                : const UnavailableCloudBackupGateway(),
            secureStore: ref.read(secureStoreProvider),
          ),
  );
});

final syncToCloudProvider = FutureProvider<bool>((ref) async {
  // Yield once before publishing command status. Riverpod forbids one
  // provider from mutating another while the first provider is synchronously
  // initializing, but the user-facing sync status must still be reset for
  // every new command.
  await Future<void>.value();
  ref.read(syncErrorMessageProvider.notifier).clear();
  if (!ref.read(cloudSyncCapabilityProvider) ||
      !(await ref.read(cloudSyncPreferenceProvider.future))) {
    return false;
  }
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null ||
      (queue.requiresAccountBinding && queue.accountId == null)) {
    return false;
  }
  try {
    await queue.replay(
      executor: (OfflineSyncQueueItem item) async {
        return _executeQueuedSyncAction(ref, item);
      },
    );

    final bool success =
        await ref.read(syncServiceProvider)?.syncToCloud() ?? false;
    if (!success) {
      ref
          .read(syncErrorMessageProvider.notifier)
          .report('Cloud synchronization is temporarily unavailable.');
      await queue.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'sync_to_cloud',
        payload: const <String, dynamic>{},
      );
    }
    return success;
  } catch (error, stackTrace) {
    ref
        .read(syncErrorMessageProvider.notifier)
        .report(
          'Cloud synchronization could not finish. Your local changes remain available.',
        );
    Logger.errorCategory(
      'Sync Errors',
      'syncToCloudProvider execution failed',
      error,
      stackTrace,
    );
    return false;
  }
});

final replayOfflineQueueProvider = FutureProvider<int>((ref) async {
  await Future<void>.value();
  ref.read(syncErrorMessageProvider.notifier).clear();
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null) {
    return 0;
  }
  return queue.replay(
    executor: (OfflineSyncQueueItem item) async {
      return _executeQueuedSyncAction(ref, item);
    },
  );
});

final offlineQueueCountProvider = FutureProvider<int>((ref) async {
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null) {
    return 0;
  }
  return queue.queuedCount();
});

final restoreFromCloudProvider = FutureProvider<bool>((ref) async {
  await Future<void>.value();
  ref.read(syncErrorMessageProvider.notifier).clear();
  try {
    if (!ref.read(cloudSyncCapabilityProvider) ||
        !(await ref.read(cloudSyncPreferenceProvider.future))) {
      return false;
    }
    final client = ref.read(supabaseClientProvider);
    if (client?.auth.currentUser == null) {
      return false;
    }
    final bool restored =
        await ref.read(syncServiceProvider)?.restoreFromCloud() ?? false;
    if (!restored) {
      ref
          .read(syncErrorMessageProvider.notifier)
          .report(
            'No cloud backup could be restored. Local data was not replaced.',
          );
    }
    if (restored) {
      ref.invalidate(tasksProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(optimizationConfigProvider);
    }
    return restored;
  } catch (error, stackTrace) {
    ref
        .read(syncErrorMessageProvider.notifier)
        .report('Cloud restore could not finish. Local data was not replaced.');
    Logger.errorCategory(
      'Sync Errors',
      'restoreFromCloudProvider execution failed',
      error,
      stackTrace,
    );
    return false;
  }
});

Future<bool> _executeQueuedSyncAction(
  Ref ref,
  OfflineSyncQueueItem item,
) async {
  final SyncService? syncService = ref.read(syncServiceProvider);
  if (syncService == null) {
    return false;
  }

  switch (item.actionType) {
    case 'sync_to_cloud':
      return syncService.syncToCloud();
    case 'sync_delta':
      return syncService.syncDelta();
    default:
      return false;
  }
}
