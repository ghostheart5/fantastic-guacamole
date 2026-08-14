import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final syncErrorMessageProvider =
    NotifierProvider<SyncErrorMessageNotifier, String?>(
      SyncErrorMessageNotifier.new,
    );

class SyncErrorMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final _sharedPrefsProvider = FutureProvider<SharedPrefsStorage>((ref) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return SharedPrefsStorage(prefs);
});

final _backupServiceProvider = Provider<BackupService?>((ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  if (!scope.isAuthenticated || scope.v2Namespace == null) {
    return null;
  }
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => BackupService(
      taskRepository: ref.read(domainTaskRepositoryProvider),
      profileStorage: HiveStorage<String>(
        'profile_box',
        hive: const HiveStoreAdapter(),
      ),
      prefs: prefs,
      secureProfileStore: ref.read(secureStoreProvider),
      secureProfileStateKey: ProfileController.canonicalStorageKeyForScope(
        scope,
      ),
      allowLegacyProfileFallback: false,
    ),
  );
});

final _offlineSyncQueueProvider = Provider<OfflineSyncQueueService?>((ref) {
  final HiveStore hive = ref.read(hiveStoreProvider);
  final String storageScope =
      ref.watch(authUserProvider).asData?.value?.id ?? 'signed_out';
  return OfflineSyncQueueService(
    HiveStorage<String>(HiveBoxes.offlineQueue, hive: hive),
    storageScope: storageScope,
  );
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(
    _sharedPrefsProvider,
  );
  final BackupService? backup = ref.watch(_backupServiceProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final String? userId = ref.watch(authUserProvider).asData?.value?.id;
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => backup == null
        ? null
        : SyncService(
            backup: backup,
            gateway: Env.isMockMode
                ? LocalTestCloudBackupGateway(prefs)
                : (Env.enableCloudSync &&
                      supabaseClient != null &&
                      userId != null)
                ? SupabaseStorageCloudBackupGateway(
                    client: supabaseClient,
                    userId: userId,
                  )
                : const UnavailableCloudBackupGateway(),
          ),
  );
});

final syncActionsProvider = Provider<SyncActions>((ref) {
  final SyncActions actions = SyncActions(ref);
  ref.onDispose(actions.dispose);
  return actions;
});

class SyncActions {
  SyncActions(this._ref);

  final Ref _ref;
  bool _cancelled = false;
  Future<void> _operationTail = Future<void>.value();
  Future<bool>? _syncInFlight;
  Future<bool>? _deltaInFlight;
  Future<bool>? _restoreInFlight;
  Future<int>? _replayInFlight;

  Future<bool> syncToCloud() {
    final Future<bool>? existing = _syncInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<bool> operation;
    operation = _serialize<bool>(_syncToCloud, false).whenComplete(() {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    });
    _syncInFlight = operation;
    return operation;
  }

  Future<int> replayOfflineQueue() {
    final Future<int>? existing = _replayInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<int> operation;
    operation = _serialize<int>(_replayOfflineQueue, 0).whenComplete(() {
      if (identical(_replayInFlight, operation)) {
        _replayInFlight = null;
      }
    });
    _replayInFlight = operation;
    return operation;
  }

  Future<bool> syncDelta() {
    final Future<bool>? existing = _deltaInFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<bool> operation;
    operation = _serialize<bool>(_syncDelta, false).whenComplete(() {
      if (identical(_deltaInFlight, operation)) {
        _deltaInFlight = null;
      }
    });
    _deltaInFlight = operation;
    return operation;
  }

  Future<bool> restoreFromCloud() {
    final Future<bool>? existing = _restoreInFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<bool> operation;
    operation = _serialize<bool>(_restoreFromCloud, false).whenComplete(() {
      if (identical(_restoreInFlight, operation)) {
        _restoreInFlight = null;
      }
    });
    _restoreInFlight = operation;
    return operation;
  }

  Future<bool> replayAndSync() => syncToCloud();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _operationTail.catchError((Object _) {});
  }

  void dispose() {
    _cancelled = true;
  }

  Future<T> _serialize<T>(Future<T> Function() operation, T cancelledValue) {
    final Future<void> previous = _operationTail.catchError((Object _) {});
    final Future<T> run = previous.then<T>((_) {
      if (_cancelled) {
        return cancelledValue;
      }
      return operation();
    });
    _operationTail = run.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return run;
  }

  Future<bool> _syncToCloud() async {
    final _SyncSession? session = _captureSession();
    if (session == null) {
      return false;
    }
    final bool hadQueuedCloudSync = (await session.queue.loadQueue()).any(
      (OfflineSyncQueueItem item) => item.dedupeKey == 'sync_to_cloud',
    );
    if (!_isSessionCurrent(session)) {
      return false;
    }
    await _replayOfflineQueueFor(session);
    if (!_isSessionCurrent(session)) {
      return false;
    }
    if (hadQueuedCloudSync) {
      final bool replaySatisfiedRequest = !(await session.queue.loadQueue())
          .any(
            (OfflineSyncQueueItem item) => item.dedupeKey == 'sync_to_cloud',
          );
      if (!_isSessionCurrent(session)) {
        return false;
      }
      if (replaySatisfiedRequest) {
        _setSyncError(session, null);
        _invalidateQueueCount(session);
        return true;
      }
    }

    final bool success = await session.service.syncToCloud(
      canContinue: () => _isSessionCurrent(session),
    );
    if (!_isSessionCurrent(session)) {
      return false;
    }
    if (!success) {
      await session.queue.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'sync_to_cloud',
        payload: const <String, dynamic>{},
        shouldContinue: () => _isSessionCurrent(session),
      );
      if (!_isSessionCurrent(session)) {
        return false;
      }
      _invalidateQueueCount(session);
      _setSyncError(
        session,
        'Cloud sync failed. The action was queued for a later retry.',
      );
      return false;
    }
    await session.queue.removeByDedupeKey(
      'sync_to_cloud',
      shouldContinue: () => _isSessionCurrent(session),
    );
    if (!_isSessionCurrent(session)) {
      return false;
    }
    _setSyncError(session, null);
    _invalidateQueueCount(session);
    return true;
  }

  Future<int> _replayOfflineQueue() async {
    final _SyncSession? session = _captureSession();
    if (session == null) {
      return 0;
    }
    return _replayOfflineQueueFor(session);
  }

  Future<int> _replayOfflineQueueFor(_SyncSession session) async {
    try {
      return await session.queue.replay(
        executor: (OfflineSyncQueueItem item) async {
          return _executeQueuedSyncAction(
            session.service,
            item,
            canContinue: () => _isSessionCurrent(session),
          );
        },
        shouldContinue: () => _isSessionCurrent(session),
      );
    } finally {
      _invalidateQueueCount(session);
    }
  }

  Future<bool> _syncDelta() async {
    final _SyncSession? session = _captureSession();
    if (session == null) {
      return false;
    }
    final bool success = await session.service.syncDelta(
      canContinue: () => _isSessionCurrent(session),
    );
    if (!_isSessionCurrent(session)) {
      return false;
    }
    if (!success) {
      await session.queue.enqueue(
        actionType: 'sync_delta',
        dedupeKey: 'sync_delta',
        shouldContinue: () => _isSessionCurrent(session),
      );
      if (!_isSessionCurrent(session)) {
        return false;
      }
      _invalidateQueueCount(session);
      _setSyncError(
        session,
        'Delta sync failed. The action was queued for a later retry.',
      );
      return false;
    }
    _setSyncError(session, null);
    return true;
  }

  Future<bool> _restoreFromCloud() async {
    final _SyncSession? session = _captureSession();
    if (session == null) {
      return false;
    }
    final queueStore = _ref.read(syncQueueStoreProvider);
    final bool restored = await session.service.restoreFromCloud(
      canContinue: () => _isSessionCurrent(session),
    );
    if (!_isSessionCurrent(session)) {
      return false;
    }
    if (!restored) {
      _setSyncError(
        session,
        'Cloud restore failed or no backup was available.',
      );
      return false;
    }

    await queueStore.overwrite(const <SyncOperation>[]);
    if (!_isSessionCurrent(session)) {
      return false;
    }
    _setSyncError(session, null);
    _ref.invalidate(tasksProvider);
    _ref.invalidate(profileProvider);
    _ref.invalidate(goalProgressProvider);
    _ref.invalidate(optimizationConfigProvider);
    return true;
  }

  _SyncSession? _captureSession() {
    if (_cancelled || !_ref.mounted) {
      return null;
    }
    final String? userId = _ref.read(authUserProvider).asData?.value?.id;
    final SyncService? service = _ref.read(syncServiceProvider);
    final OfflineSyncQueueService? queue = _ref.read(_offlineSyncQueueProvider);
    final supabaseClient = _ref.read(supabaseClientProvider);
    if (userId == null || service == null || queue == null) {
      return null;
    }
    return _SyncSession(
      service: service,
      queue: queue,
      remainsAuthenticated: () =>
          Env.isMockMode || supabaseClient?.auth.currentUser?.id == userId,
    );
  }

  bool _isSessionCurrent(_SyncSession session) {
    return !_cancelled && session.remainsAuthenticated();
  }

  void _setSyncError(_SyncSession session, String? message) {
    if (!_isSessionCurrent(session) || !_ref.mounted) {
      return;
    }
    _ref.read(syncErrorMessageProvider.notifier).set(message);
  }

  void _invalidateQueueCount(_SyncSession session) {
    if (!_isSessionCurrent(session) || !_ref.mounted) {
      return;
    }
    _ref.invalidate(offlineQueueCountProvider);
  }
}

class _SyncSession {
  const _SyncSession({
    required this.service,
    required this.queue,
    required this.remainsAuthenticated,
  });

  final SyncService service;
  final OfflineSyncQueueService queue;
  final bool Function() remainsAuthenticated;
}

final syncToCloudProvider = FutureProvider<bool>(
  (ref) => ref.read(syncActionsProvider).syncToCloud(),
);

final replayOfflineQueueProvider = FutureProvider<int>(
  (ref) => ref.read(syncActionsProvider).replayOfflineQueue(),
);

final offlineQueueCountProvider = FutureProvider<int>((ref) async {
  final OfflineSyncQueueService? queue = ref.read(_offlineSyncQueueProvider);
  if (queue == null) {
    return 0;
  }
  return queue.queuedCount();
});

final restoreFromCloudProvider = FutureProvider<bool>(
  (ref) => ref.read(syncActionsProvider).restoreFromCloud(),
);

Future<bool> _executeQueuedSyncAction(
  SyncService syncService,
  OfflineSyncQueueItem item, {
  required bool Function() canContinue,
}) async {
  if (!canContinue()) {
    return false;
  }

  switch (item.actionType) {
    case 'sync_to_cloud':
      return syncService.syncToCloud(canContinue: canContinue);
    case 'sync_delta':
      return syncService.syncDelta(canContinue: canContinue);
    default:
      return false;
  }
}
