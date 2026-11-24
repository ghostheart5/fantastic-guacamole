import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/cloud_backup_status_store.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:fantastic_guacamole/data/services/sync_service.dart'
    show
        CloudBackupDiscardOutcome,
        CloudBackupKeyCheck,
        CloudBackupPresence,
        RecoveryKeyImportOutcome;

/// What the user should know about the full cloud backup after the last
/// automatic sync. Shown as a calm status in Settings, not as a sync error.
enum CloudBackupAttention {
  none,

  /// A full cloud backup exists that this device did not make or restore, so
  /// automatic backup cannot keep it current until one confirmed full backup.
  fullBackupNotLinked,

  /// The full cloud backup changed on another device since this device last
  /// backed up. Nothing was uploaded.
  changedOnAnotherDevice,
}

final cloudBackupAttentionProvider =
    NotifierProvider<CloudBackupAttentionNotifier, CloudBackupAttention>(
      CloudBackupAttentionNotifier.new,
    );

class CloudBackupAttentionNotifier extends Notifier<CloudBackupAttention> {
  @override
  CloudBackupAttention build() {
    // A status about one account's backup never carries over to another.
    ref.watch(accountStorageScopeProvider);
    return CloudBackupAttention.none;
  }

  void set(CloudBackupAttention value) => state = value;
}

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

enum CloudRestoreWarning { legacyCleanupPending, remindersPending }

final cloudRestoreWarningsProvider =
    NotifierProvider<CloudRestoreWarningsNotifier, Set<CloudRestoreWarning>>(
      CloudRestoreWarningsNotifier.new,
    );

class CloudRestoreWarningsNotifier extends Notifier<Set<CloudRestoreWarning>> {
  @override
  Set<CloudRestoreWarning> build() => {};
  void clear() => state = {};
  void add(CloudRestoreWarning warning) => state = {...state, warning};
}

final restoredReminderReconciliationProvider =
    Provider<Future<bool> Function()>(
      (ref) => () async {
        final owner = AccountOperation.capture(ref);
        owner.check();
        final reflection = ref.read(reflectionReminderServiceProvider);
        final reminders = ref.read(reminderOrchestratorServiceProvider);
        final scheduler = ref.read(notificationSchedulerProvider);
        final goals = ref.read(getGoalsUseCaseProvider).call();
        final habits = await owner.wait(
          ref.read(getHabitsUseCaseProvider).call(),
        );
        // Read current OS permission; never open the permission prompt here.
        bool granted = false;
        bool permissionKnown = false;
        try {
          granted = await owner.wait(scheduler.init(requestPermissions: false));
          permissionKnown = true;
        } on Object {
          owner.check();
          // Cancellation still runs if querying OS permission failed.
        }
        Future<bool> attempt(Future<bool> Function() action) async {
          try {
            return await owner.wait(action());
          } on Object {
            owner.check();
            return false;
          }
        }

        final reflected = await attempt(
          () => reflection.reconcileAfterRestore(
            permissionGranted: granted,
            shouldContinue: () => owner.isCurrent,
          ),
        );
        final planned = await attempt(
          () => reminders.reconcileAfterRestore(
            goals: goals,
            habits: habits,
            permissionGranted: granted,
            shouldContinue: () => owner.isCurrent,
          ),
        );
        return permissionKnown && reflected && planned;
      },
    );

/// Local backup dependencies must finish loading before a transfer begins.
final cloudBackupPreferencesProvider = FutureProvider<SharedPrefsStorage>((
  ref,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return SharedPrefsStorage(prefs);
});

final _backupServiceProvider = Provider<BackupService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    cloudBackupPreferencesProvider,
  );
  final scope = ref.watch(accountStorageScopeProvider);
  final legacyOwnership = ref.watch(accountLegacyOwnershipProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) {
      final AccountScopedSharedPrefsStorage scopedPrefs =
          AccountScopedSharedPrefsStorage(
            delegate: prefs,
            scope: scope,
            legacyOwnership: legacyOwnership,
          );
      return BackupService(
        taskRepository: ref.watch(domainTaskRepositoryProvider),
        goalRepository: ref.watch(domainGoalRepositoryProvider),
        habitRepository: ref.watch(domainHabitRepositoryProvider),
        noteRepository: ref.watch(domainNoteRepositoryProvider),
        taskOccurrenceRepository: ref.watch(taskOccurrenceRepositoryProvider),
        habitOccurrenceRepository: ref.watch(habitOccurrenceRepositoryProvider),
        decisionOutcomeRepository: ref.watch(decisionOutcomeRepositoryProvider),
        timelineRepository: ref.watch(domainTimelineRepositoryProvider),
        profileStorage: AccountScopedHiveStorage(
          baseBox: HiveBoxes.profile,
          scope: scope,
          hive: ref.read(hiveStoreProvider),
          legacyOwnership: legacyOwnership,
        ),
        prefs: scopedPrefs,
        scope: scope,
        secureProfileStore: ref
            .read(secureStoreProvider)
            .forAccount(scope, legacyOwnership: legacyOwnership),
      );
    },
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
    AccountScopedHiveStorage(
      baseBox: HiveBoxes.offlineQueue,
      scope: scope,
      hive: hive,
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
    accountId: scope.isWritable ? scope.rawUserId : null,
    enforceAccountBinding: true,
  );
});

OfflineSyncQueueService? _boundQueue(Ref ref) {
  return ref.watch(offlineSyncQueueProvider);
}

/// Per-account record of the last cloud backup this device wrote, restored or
/// matched. Null while preferences load or when no account is signed in.
final cloudBackupStatusStoreProvider = Provider<CloudBackupStatusStore?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    cloudBackupPreferencesProvider,
  );
  final scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  final legacyOwnership = ref.watch(accountLegacyOwnershipProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => CloudBackupStatusStore(
      AccountScopedSharedPrefsStorage(
        delegate: prefs,
        scope: scope,
        legacyOwnership: legacyOwnership,
      ),
    ),
  );
});

/// When the cloud backup this device last wrote, restored or matched was
/// made. Null when this device has no record of one.
final lastCloudBackupProvider = FutureProvider<DateTime?>((ref) async {
  await ref.watch(cloudBackupPreferencesProvider.future);
  return ref.watch(cloudBackupStatusStoreProvider)?.read()?.backedUpAt;
});

/// Per-account record that the user confirmed saving the recovery key. Null
/// while preferences load or when no account is signed in.
final recoveryKeySavedStoreProvider = Provider<RecoveryKeySavedStore?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    cloudBackupPreferencesProvider,
  );
  final scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  final legacyOwnership = ref.watch(accountLegacyOwnershipProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => RecoveryKeySavedStore(
      AccountScopedSharedPrefsStorage(
        delegate: prefs,
        scope: scope,
        legacyOwnership: legacyOwnership,
      ),
    ),
  );
});

/// Whether the user confirmed saving this account's recovery key. Cloud
/// Backup is turned on, and a first full backup made, only after this.
final recoveryKeySavedProvider =
    AsyncNotifierProvider<RecoveryKeySavedNotifier, bool>(
      RecoveryKeySavedNotifier.new,
    );

class RecoveryKeySavedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    await ref.watch(cloudBackupPreferencesProvider.future);
    return ref.watch(recoveryKeySavedStoreProvider)?.read() ?? false;
  }

  /// Remembers the confirmation for the account that is current now.
  Future<void> markSaved() async {
    final owner = AccountOperation.capture(ref);
    try {
      await owner.wait(ref.read(cloudBackupPreferencesProvider.future));
    } on StaleAccountOperation {
      return;
    }
    final RecoveryKeySavedStore? store = ref.read(
      recoveryKeySavedStoreProvider,
    );
    if (store == null || !owner.isCurrent) return;
    await store.markSaved();
    if (owner.isCurrent) state = const AsyncData<bool>(true);
  }
}

/// Whether this device holds a recovery key and whether it opens the current
/// cloud backup. Null when Cloud Backup is off or unavailable. Read-only (see
/// [SyncService.checkCloudBackupKey]); refreshed after every sync, backup,
/// restore, key import and discard.
final cloudBackupKeyStatusProvider = FutureProvider<CloudBackupKeyCheck?>((
  ref,
) async {
  if (!ref.watch(cloudSyncCapabilityProvider)) return null;
  if (!await ref.watch(cloudSyncPreferenceProvider.future)) return null;
  await ref.watch(cloudBackupPreferencesProvider.future);
  final SyncService? service = ref.watch(syncServiceProvider);
  return service?.checkCloudBackupKey();
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final bool userEnabled =
      ref.watch(cloudSyncPreferenceProvider).asData?.value ?? false;
  return _buildSyncService(
    ref,
    cloudReachable: userEnabled,
    recordBackups: true,
  );
});

/// A service used only for read-only key checks while the user is turning
/// Cloud Backup on: checking a saved key and looking for an existing backup
/// before a new key is made. It reaches the account's own cloud backup
/// whether or not Cloud Backup is on yet, and is never used to upload.
final cloudBackupKeyCheckServiceProvider = Provider<SyncService?>(
  (ref) => _buildSyncService(ref, cloudReachable: true, recordBackups: false),
);

SyncService? _buildSyncService(
  Ref ref, {
  required bool cloudReachable,
  required bool recordBackups,
}) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    cloudBackupPreferencesProvider,
  );
  final BackupService? backup = ref.watch(_backupServiceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final scope = ref.watch(accountStorageScopeProvider);
  final legacyOwnership = ref.watch(accountLegacyOwnershipProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) {
      if (backup == null) return null;
      final AccountScopedSharedPrefsStorage scopedPrefs =
          AccountScopedSharedPrefsStorage(
            delegate: prefs,
            scope: scope,
            legacyOwnership: legacyOwnership,
          );
      return SyncService(
        backup: backup,
        gateway: Env.isMockMode
            ? LocalTestCloudBackupGateway(scopedPrefs)
            : (Env.enableCloudSync && cloudReachable && supabaseClient != null)
            ? SupabaseCasCloudBackupGateway(
                client: supabaseClient,
                expectedUserId: scope.isWritable ? scope.rawUserId ?? '' : '',
              )
            : const UnavailableCloudBackupGateway(),
        secureStore: ref.read(secureStoreProvider),
        statusStore: recordBackups
            ? ref.watch(cloudBackupStatusStoreProvider)
            : null,
        expectedAccountId: scope.isWritable ? scope.rawUserId : null,
        currentAccountId: () => supabaseClient?.auth.currentUser?.id,
      );
    },
  );
}

Future<SyncService?> _readyKeyCheckService(Ref ref) async {
  final service = ref.read(cloudBackupKeyCheckServiceProvider);
  if (service != null) return service;
  final owner = AccountOperation.capture(ref);
  await owner.wait(ref.read(cloudBackupPreferencesProvider.future));
  return ref.read(cloudBackupKeyCheckServiceProvider);
}

/// Checks a recovery key saved elsewhere while Cloud Backup is still off, as
/// part of turning it on. Installs it only when safe (see
/// [SyncService.importRecoveryKey]) and records it as saved. Never changes
/// the Cloud Backup setting: the caller turns it on only after this accepts.
final recoveryKeyRestoreBeforeEnablingProvider =
    Provider<Future<RecoveryKeyImportOutcome> Function(String)>(
      (ref) => (String recoveryKey) async {
        final owner = AccountOperation.capture(ref);
        if (!owner.isCurrent) return RecoveryKeyImportOutcome.accountChanged;
        if (!ref.read(cloudSyncCapabilityProvider)) {
          return RecoveryKeyImportOutcome.cloudUnavailable;
        }
        final SyncService? service;
        try {
          service = await _readyKeyCheckService(ref);
        } on StaleAccountOperation {
          return RecoveryKeyImportOutcome.accountChanged;
        }
        if (!owner.isCurrent) return RecoveryKeyImportOutcome.accountChanged;
        if (service == null) return RecoveryKeyImportOutcome.cloudUnavailable;
        final RecoveryKeyImportOutcome outcome = await service
            .importRecoveryKey(recoveryKey);
        if (!owner.isCurrent) return RecoveryKeyImportOutcome.accountChanged;
        if (outcome == RecoveryKeyImportOutcome.installed ||
            outcome == RecoveryKeyImportOutcome.installedUnverified) {
          await ref.read(recoveryKeySavedProvider.notifier).markSaved();
        }
        ref.invalidate(cloudBackupKeyStatusProvider);
        return outcome;
      },
    );

/// Read-only: whether the account already has an encrypted cloud backup.
/// Asked before a new key is created, because a new key could never open it.
final cloudBackupPresenceProvider =
    Provider<Future<CloudBackupPresence> Function()>(
      (ref) => () async {
        final owner = AccountOperation.capture(ref);
        if (!owner.isCurrent || !ref.read(cloudSyncCapabilityProvider)) {
          return CloudBackupPresence.unknown;
        }
        final SyncService? service;
        try {
          service = await _readyKeyCheckService(ref);
        } on StaleAccountOperation {
          return CloudBackupPresence.unknown;
        }
        if (service == null || !owner.isCurrent) {
          return CloudBackupPresence.unknown;
        }
        final CloudBackupPresence presence = await service.findCloudBackup();
        return owner.isCurrent ? presence : CloudBackupPresence.unknown;
      },
    );

/// Installs a pasted backup recovery key only after it is proven against the
/// account's current cloud backup (see [SyncService.importRecoveryKey]). When
/// the backup cannot be reached the stored key is left unchanged.
final backupRecoveryKeyImportProvider =
    Provider<Future<RecoveryKeyImportOutcome> Function(String)>(
      (ref) => (String recoveryKey) async {
        final owner = AccountOperation.capture(ref);
        if (!owner.isCurrent) return RecoveryKeyImportOutcome.accountChanged;
        // The gateway depends on the Cloud Backup choice; wait for it so a
        // still-loading preference is not mistaken for an unreachable cloud.
        final SyncService? service;
        try {
          if (!await owner.wait(ref.read(cloudSyncPreferenceProvider.future))) {
            return RecoveryKeyImportOutcome.cloudBackupOff;
          }
          service = await _readySyncService(ref);
        } on StaleAccountOperation {
          return RecoveryKeyImportOutcome.accountChanged;
        }
        if (!owner.isCurrent) return RecoveryKeyImportOutcome.accountChanged;
        if (service == null) return RecoveryKeyImportOutcome.cloudUnavailable;
        final RecoveryKeyImportOutcome outcome = await service
            .importRecoveryKey(recoveryKey);
        if (!owner.isCurrent) return outcome;
        if (outcome == RecoveryKeyImportOutcome.installed ||
            outcome == RecoveryKeyImportOutcome.installedUnverified) {
          // The user pasted this key from where they keep it.
          await ref.read(recoveryKeySavedProvider.notifier).markSaved();
        }
        ref.invalidate(cloudBackupKeyStatusProvider);
        return outcome;
      },
    );

/// Discards a cloud backup this device cannot read so backup can start over
/// (see [SyncService.discardUnreadableCloudBackup]). Works only once the
/// server allows deleting one's own backup row.
final cloudBackupDiscardProvider =
    Provider<Future<CloudBackupDiscardOutcome> Function()>(
      (ref) => () async {
        final owner = AccountOperation.capture(ref);
        if (!owner.isCurrent) return CloudBackupDiscardOutcome.accountChanged;
        final SyncService? service;
        try {
          if (!ref.read(cloudSyncCapabilityProvider) ||
              !await owner.wait(ref.read(cloudSyncPreferenceProvider.future))) {
            return CloudBackupDiscardOutcome.unavailable;
          }
          service = await _readySyncService(ref);
        } on StaleAccountOperation {
          return CloudBackupDiscardOutcome.accountChanged;
        }
        if (!owner.isCurrent) return CloudBackupDiscardOutcome.accountChanged;
        if (service == null) return CloudBackupDiscardOutcome.unavailable;
        final CloudBackupDiscardOutcome outcome = await service
            .discardUnreadableCloudBackup();
        if (!owner.isCurrent) return CloudBackupDiscardOutcome.accountChanged;
        if (outcome == CloudBackupDiscardOutcome.discarded) {
          ref.invalidate(lastCloudBackupProvider);
          ref
              .read(cloudBackupAttentionProvider.notifier)
              .set(CloudBackupAttention.none);
        }
        ref.invalidate(cloudBackupKeyStatusProvider);
        return outcome;
      },
    );

Future<SyncService?> _readySyncService(Ref ref) async {
  final service = ref.read(syncServiceProvider);
  if (service != null) return service;
  // The synchronous service is initially null while its preferences load.
  // Wait for that dependency, without crossing an account transition.
  final owner = AccountOperation.capture(ref);
  await owner.wait(ref.read(cloudBackupPreferencesProvider.future));
  return ref.read(syncServiceProvider);
}

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
        await (await _readySyncService(ref))?.syncDeltaOutcome() ??
        CloudSyncOutcome.unavailable;
    ref.invalidate(lastCloudBackupProvider);
    ref.invalidate(cloudBackupKeyStatusProvider);
    final CloudBackupAttentionNotifier attention = ref.read(
      cloudBackupAttentionProvider.notifier,
    );
    if (outcome == CloudSyncOutcome.fullBackupNotLinked) {
      // Expected after an update or on a device that never backed up: a calm
      // Settings status, not a sync error repeated on every run.
      attention.set(CloudBackupAttention.fullBackupNotLinked);
      return false;
    }
    if (outcome == CloudSyncOutcome.synced) {
      attention.set(CloudBackupAttention.none);
    } else if (outcome == CloudSyncOutcome.conflict) {
      attention.set(CloudBackupAttention.changedOnAnotherDevice);
    }
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

/// Only the confirmed full-backup button invokes this provider. Expanded
/// planning data is never queued for an automatic legacy upload.
final backupPlanningToCloudProvider = FutureProvider<bool>((ref) async {
  await Future<void>.value();
  final owner = AccountOperation.capture(ref);
  if (!owner.isCurrent) return false;
  ref.read(syncErrorMessageProvider.notifier).clear();
  if (!ref.read(cloudSyncCapabilityProvider) ||
      !await owner.wait(ref.read(cloudSyncPreferenceProvider.future))) {
    return false;
  }
  try {
    final service = await _readySyncService(ref);
    owner.check();
    final outcome =
        await service?.backupPlanningToCloud(
          shouldContinue: () =>
              owner.isCurrent &&
              (ref.read(cloudSyncPreferenceProvider).asData?.value ?? false),
        ) ??
        CloudSyncOutcome.unavailable;
    if (!owner.isCurrent) return false;
    ref.invalidate(lastCloudBackupProvider);
    ref.invalidate(cloudBackupKeyStatusProvider);
    if (outcome == CloudSyncOutcome.synced) {
      ref
          .read(cloudBackupAttentionProvider.notifier)
          .set(CloudBackupAttention.none);
    }
    if (outcome != CloudSyncOutcome.synced) {
      ref
          .read(syncErrorMessageProvider.notifier)
          .report(_syncOutcomeMessage(outcome));
    }
    return outcome == CloudSyncOutcome.synced;
  } on Object {
    if (owner.isCurrent) {
      ref
          .read(syncErrorMessageProvider.notifier)
          .report(
            'Planning backup could not be verified. Keep your local data and retry.',
          );
    }
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
  ref.read(cloudRestoreWarningsProvider.notifier).clear();
  final owner = AccountOperation.capture(ref);
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
        await (await _readySyncService(ref))?.restoreFromCloud() ??
        CloudRestoreOutcome.unavailable;
    if (!owner.isCurrent) return false;
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
      if (outcome == CloudRestoreOutcome.restoredLegacyCleanupPending) {
        ref
            .read(cloudRestoreWarningsProvider.notifier)
            .add(CloudRestoreWarning.legacyCleanupPending);
      }
      ref.invalidate(allTasksProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(habitsProvider);
      ref.invalidate(notesProvider);
      ref.invalidate(timelineProvider);
      ref.invalidate(habitOccurrencesProvider);
      ref.invalidate(decisionOutcomesProvider);
      ref.invalidate(taskOccurrenceCoordinatorProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(optimizationConfigProvider);
      ref.invalidate(cloudSyncPreferenceProvider);
      ref.invalidate(lastCloudBackupProvider);
      ref.invalidate(cloudBackupKeyStatusProvider);
      ref
          .read(cloudBackupAttentionProvider.notifier)
          .set(CloudBackupAttention.none);
      ref.read(restoredSettingsRevisionProvider.notifier).bump();
      bool remindersComplete = false;
      try {
        remindersComplete = await ref.read(
          restoredReminderReconciliationProvider,
        )();
      } on Object catch (error, stackTrace) {
        Logger.errorCategory(
          'Sync Errors',
          'Restored reminder reconciliation needs retry',
          error,
          stackTrace,
        );
      }
      if (!owner.isCurrent) return false;
      ref.invalidate(automationNotificationsProvider);
      if (!remindersComplete) {
        ref
            .read(cloudRestoreWarningsProvider.notifier)
            .add(CloudRestoreWarning.remindersPending);
        ref
            .read(syncErrorMessageProvider.notifier)
            .report(
              'Your backup was restored, but device reminders need attention in Settings.',
            );
      }
    }
    return restored;
  } catch (error, stackTrace) {
    if (!owner.isCurrent) return false;
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
  final SyncService? syncService = await _readySyncService(ref);
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
      'The cloud backup changed since this device last backed up, usually on another device. Nothing was uploaded. Back up all planning data would replace that newer copy with this device\'s data.',
    CloudSyncOutcome.fullBackupNotLinked =>
      'Press Back up all planning data once to keep your full backup up to date automatically.',
    CloudSyncOutcome.unavailable =>
      'Cloud synchronization is temporarily unavailable. Local changes remain available.',
    CloudSyncOutcome.uploadFailed =>
      'Cloud synchronization could not upload changes. Local changes remain available.',
  };
}
