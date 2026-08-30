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
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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

/// Build-time capability gate kept injectable so synchronization behavior can be
/// verified without changing production environment variables.
final cloudSyncCapabilityProvider = Provider<bool>(
  (Ref ref) => Env.enableCloudSync,
);

final cloudRestoreCapabilityProvider = Provider<bool>(
  (Ref ref) => Env.enableCloudRestore,
);

/// Account-bound production queue. Tests and alternate local runtimes may
/// inject an isolated queue while preserving the same replay semantics.
final offlineSyncQueueProvider = Provider<OfflineSyncQueueService?>((ref) {
  final HiveStore hive = ref.read(hiveStoreProvider);
  final scope = ref.watch(accountStorageScopeProvider);
  return OfflineSyncQueueService(
    HiveStorage<String>(HiveBoxes.offlineQueue, hive: hive),
    accountId: scope.isWritable ? scope.rawUserId : null,
    enforceAccountBinding: true,
  );
});

OfflineSyncQueueService? _boundQueue(Ref ref) {
  return ref.watch(offlineSyncQueueProvider);
}

final syncServiceProvider = Provider<SyncService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  final BackupService? backup = ref.watch(_backupServiceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final scope = ref.watch(accountStorageScopeProvider);
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
                ? SupabaseCasCloudBackupGateway(
                    client: supabaseClient,
                    expectedUserId: scope.isWritable
                        ? scope.rawUserId ?? ''
                        : '',
                  )
                : const UnavailableCloudBackupGateway(),
            secureStore: ref.read(secureStoreProvider),
            expectedAccountId: scope.isWritable ? scope.rawUserId : null,
            currentAccountId: () => supabaseClient?.auth.currentUser?.id,
          ),
  );
});

final syncToCloudProvider = FutureProvider<bool>((ref) async {
  // Yield once before publishing synchronization status. Riverpod forbids one
  // provider from mutating another while the first provider is synchronously
  // initializing, but the user-facing sync status must still be reset for
  // every new synchronization request.
  await Future<void>.value();
  ref.read(syncErrorMessageProvider.notifier).clear();
  if (!ref.read(cloudSyncCapabilityProvider)) {
    ref
        .read(syncErrorMessageProvider.notifier)
        .report('Cloud synchronization is unavailable in this build.');
    return false;
  }
  if (!(await ref.read(cloudSyncPreferenceProvider.future))) {
    ref
        .read(syncErrorMessageProvider.notifier)
        .report('Cloud synchronization is turned off in Settings.');
    return false;
  }
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null ||
      (queue.requiresAccountBinding && queue.accountId == null)) {
    ref
        .read(syncErrorMessageProvider.notifier)
        .report('Sign in again before synchronizing this account.');
    return false;
  }
  try {
    await queue.replay(
      executor: (OfflineSyncQueueItem item) async {
        return _executeQueuedSyncAction(ref, item);
      },
    );

    final CloudSyncOutcome outcome =
        await ref.read(syncServiceProvider)?.syncDeltaOutcome() ??
        CloudSyncOutcome.unavailable;
    final bool success = outcome == CloudSyncOutcome.synced;
    if (!success) {
      ref
          .read(syncErrorMessageProvider.notifier)
          .report(_syncOutcomeMessage(outcome));
      if (outcome == CloudSyncOutcome.unavailable ||
          outcome == CloudSyncOutcome.uploadFailed) {
        await queue.enqueue(
          actionType: 'sync_delta',
          dedupeKey: 'sync_delta',
          payload: const <String, dynamic>{},
        );
      }
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

final offlineDeadLetterCountProvider = FutureProvider<int>((ref) async {
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null) {
    return 0;
  }
  return queue.deadLetteredCount();
});

final retryOfflineDeadLettersProvider = FutureProvider<int>((ref) async {
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null) {
    return 0;
  }
  return queue.retryDeadLetters();
});

final pruneOfflineDeadLettersProvider = FutureProvider<int>((ref) async {
  final OfflineSyncQueueService? queue = _boundQueue(ref);
  if (queue == null) {
    return 0;
  }
  return queue.pruneExpiredDeadLetters();
});

final restoreFromCloudProvider = FutureProvider<bool>((ref) async {
  await Future<void>.value();
  ref.read(syncErrorMessageProvider.notifier).clear();
  try {
    if (!ref.read(cloudRestoreCapabilityProvider) ||
        !(await ref.read(cloudSyncPreferenceProvider.future))) {
      return false;
    }
    final client = ref.read(supabaseClientProvider);
    if (client?.auth.currentUser == null) {
      return false;
    }
    final CloudRestoreOutcome outcome =
        await ref.read(syncServiceProvider)?.restoreFromCloud() ??
        CloudRestoreOutcome.unavailable;
    final bool restored =
        outcome == CloudRestoreOutcome.restored ||
        outcome == CloudRestoreOutcome.restoredLegacyCleanupPending;
    final String? failureMessage = switch (outcome) {
      CloudRestoreOutcome.restored => null,
      CloudRestoreOutcome.restoredLegacyCleanupPending =>
        'Your backup was restored from its verified encrypted copy, but an older cloud copy still needs secure cleanup.',
      CloudRestoreOutcome.notFound =>
        'No cloud backup exists for this account. Local data was not changed.',
      CloudRestoreOutcome.unavailable =>
        'Cloud backup is temporarily unavailable. Local data was not changed.',
      CloudRestoreOutcome.recoveryKeyRequired =>
        'This cloud backup needs its recovery key before it can be restored. Local data was not changed.',
      CloudRestoreOutcome.conflict =>
        'Cloud backup changed on another device. Nothing was restored; retry to review the newest version.',
      CloudRestoreOutcome.malformed =>
        'The cloud backup could not be verified. Local data was not changed.',
      CloudRestoreOutcome.ownerMismatch || CloudRestoreOutcome.accountChanged =>
        'Cloud restore stopped because the signed-in account changed. Local data was not changed.',
      CloudRestoreOutcome.migrationFailed =>
        'The older cloud backup could not be secured before restore. Local data was not changed.',
      CloudRestoreOutcome.disabled =>
        'Cloud restore is unavailable in this build. Local data was not changed.',
    };
    if (failureMessage != null) {
      ref.read(syncErrorMessageProvider.notifier).report(failureMessage);
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
        .report(
          'Cloud restore could not finish. Local data may have changed; verify it before making further changes.',
        );
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
  final scope = ref.read(accountStorageScopeProvider);
  final String? currentAccountId = scope.isWritable ? scope.rawUserId : null;
  final String? authenticatedUserId = ref
      .read(supabaseClientProvider)
      ?.auth
      .currentUser
      ?.id;
  if (item.accountId == null || item.accountId != currentAccountId) {
    return false;
  }
  if (authenticatedUserId != null && item.accountId != authenticatedUserId) {
    return false;
  }
  final SyncService? syncService = ref.read(syncServiceProvider);
  if (syncService == null) {
    return false;
  }

  switch (item.actionType) {
    case 'sync_to_cloud':
    case 'sync_delta':
      return await syncService.syncDeltaOutcome() == CloudSyncOutcome.synced;
    default:
      return false;
  }
}

String _syncOutcomeMessage(CloudSyncOutcome outcome) {
  return switch (outcome) {
    CloudSyncOutcome.synced => 'Cloud synchronization completed.',
    CloudSyncOutcome.disabled =>
      'Cloud synchronization is unavailable in this build.',
    CloudSyncOutcome.accountChanged || CloudSyncOutcome.ownerMismatch =>
      'Cloud synchronization stopped because the signed-in account changed.',
    CloudSyncOutcome.malformed =>
      'The existing cloud backup could not be verified. Nothing was uploaded.',
    CloudSyncOutcome.recoveryKeyRequired =>
      'This cloud backup needs its recovery key before synchronization can continue.',
    CloudSyncOutcome.conflict =>
      'Cloud data changed on another device. Nothing was overwritten; retry to merge the newest version.',
    CloudSyncOutcome.unavailable =>
      'Cloud synchronization is temporarily unavailable. Local changes remain available.',
    CloudSyncOutcome.uploadFailed =>
      'Cloud synchronization could not upload changes. Local changes remain available.',
  };
}
