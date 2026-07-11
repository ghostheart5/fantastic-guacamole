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
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final _offlineSyncQueueProvider = Provider<OfflineSyncQueueService?>((ref) {
  final HiveStore hive = ref.read(hiveStoreProvider);
  return OfflineSyncQueueService(
    HiveStorage<String>(HiveBoxes.offlineQueue, hive: hive),
  );
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  final BackupService? backup = ref.watch(_backupServiceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => backup == null
        ? null
        : SyncService(
            backup: backup,
            gateway: Env.isMockMode
                ? LocalTestCloudBackupGateway(prefs)
                : (Env.enableCloudSync && supabaseClient != null)
                ? SupabaseStorageCloudBackupGateway(client: supabaseClient)
                : const UnavailableCloudBackupGateway(),
          ),
  );
});

final syncToCloudProvider = FutureProvider<bool>((ref) async {
  final OfflineSyncQueueService? queue = ref.read(_offlineSyncQueueProvider);
  try {
    await queue?.replay(
      executor: (OfflineSyncQueueItem item) async {
        return _executeQueuedSyncAction(ref, item);
      },
    );

    final bool success =
        await ref.read(syncServiceProvider)?.syncToCloud() ?? false;
    if (!success) {
      await queue?.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'sync_to_cloud',
        payload: const <String, dynamic>{},
      );
    }
    return success;
  } catch (error, stackTrace) {
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
  final OfflineSyncQueueService? queue = ref.read(_offlineSyncQueueProvider);
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
  final OfflineSyncQueueService? queue = ref.read(_offlineSyncQueueProvider);
  if (queue == null) {
    return 0;
  }
  return queue.queuedCount();
});

final restoreFromCloudProvider = FutureProvider<bool>((ref) async {
  try {
    final bool restored =
        await ref.read(syncServiceProvider)?.restoreFromCloud() ?? false;
    if (restored) {
      ref.invalidate(tasksProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(optimizationConfigProvider);
    }
    return restored;
  } catch (error, stackTrace) {
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
