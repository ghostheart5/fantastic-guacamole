import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDirectory;
  late SharedPrefsStorage prefs;
  late HiveStorage<String> profileStorage;
  late _TestHiveStore hiveStore;
  late _MemoryTaskRepository repository;
  late _SequencedCloudBackupGateway gateway;
  late ProviderContainer container;

  setUp(() async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'test-user',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cloud_sync_enabled_v1.${scope.v2Namespace}': true,
    });
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_sync_provider_',
    );
    Hive.init(hiveDirectory.path);

    prefs = SharedPrefsStorage(await SharedPreferences.getInstance());
    hiveStore = _TestHiveStore();
    profileStorage = HiveStorage<String>('profile_box', hive: hiveStore);
    repository = _MemoryTaskRepository();

    final BackupService backupService = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: prefs,
    );

    gateway = _SequencedCloudBackupGateway(<bool>[false, true, true]);

    container = ProviderContainer(
      overrides: [
        hiveStoreProvider.overrideWithValue(hiveStore),
        accountStorageScopeProvider.overrideWithValue(scope),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        cloudSyncCapabilityProvider.overrideWithValue(true),
        offlineSyncQueueProvider.overrideWithValue(
          OfflineSyncQueueService(
            HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
            accountId: 'test-user',
            enforceAccountBinding: true,
          ),
        ),
        syncServiceProvider.overrideWithValue(
          SyncService(
            backup: backupService,
            gateway: gateway,
            expectedAccountId: 'test-user',
            currentAccountId: () => 'test-user',
            syncEnabled: true,
            restoreEnabled: true,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await profileStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('syncToCloudProvider returns false when upload fails', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Queue me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );

    final bool first = await container.read(syncToCloudProvider.future);
    expect(first, isFalse);
    expect(gateway.uploadAttempts, 1);
  });

  for (final changeAccount in [false, true]) {
    test(
      changeAccount
          ? 'account transition while preferences load prevents first backup'
          : 'first backup waits for local preferences before transferring',
      () async {
        container.dispose();
        final ready = Completer<SharedPrefsStorage>();
        final loadingStarted = Completer<void>();
        gateway.uploadShouldAlwaysSucceed = true;
        final service = SyncService(
          backup: BackupService(
            taskRepository: repository,
            profileStorage: profileStorage,
            prefs: prefs,
          ),
          gateway: gateway,
          expectedAccountId: 'test-user',
          currentAccountId: () => 'test-user',
          syncEnabled: true,
          restoreEnabled: true,
        );
        container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated('test-user'),
            ),
            cloudSyncCapabilityProvider.overrideWithValue(true),
            cloudBackupPreferencesProvider.overrideWith((ref) {
              loadingStarted.complete();
              return ready.future;
            }),
            offlineSyncQueueProvider.overrideWithValue(
              OfflineSyncQueueService(
                HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
                accountId: 'test-user',
                enforceAccountBinding: true,
              ),
            ),
            syncServiceProvider.overrideWith(
              (ref) => ref.watch(cloudBackupPreferencesProvider).hasValue
                  ? service
                  : null,
            ),
          ],
        );
        var completed = false;
        final pending = container.read(syncToCloudProvider.future);
        unawaited(pending.then((_) => completed = true));
        await loadingStarted.future;
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect(gateway.uploadAttempts, 0);
        if (changeAccount) {
          container
              .read(authSessionBoundaryProvider.notifier)
              .begin(userId: 'other-user', isTransitioning: true);
        }
        ready.complete(prefs);
        expect(await pending, !changeAccount);
        expect(gateway.uploadAttempts, changeAccount ? 0 : 1);
        if (!changeAccount) {
          expect(container.read(syncErrorMessageProvider), isNull);
        }
      },
    );
  }

  test(
    'provider queues a safe delta retry after a transient read failure',
    () async {
      final OfflineSyncQueueService queue = container.read(
        offlineSyncQueueProvider,
      )!;
      gateway.readOverride = const CloudBackupReadResult.unavailable();

      expect(await container.read(syncToCloudProvider.future), isFalse);
      expect(gateway.uploadAttempts, 0);
      expect(container.read(syncErrorMessageProvider), isNotEmpty);
      expect(await queue.queuedCount(), 1);
    },
  );

  test('provider does not queue malformed or owner-mismatched reads', () async {
    final OfflineSyncQueueService queue = container.read(
      offlineSyncQueueProvider,
    )!;
    for (final CloudBackupReadResult failure in <CloudBackupReadResult>[
      const CloudBackupReadResult.malformed(),
      const CloudBackupReadResult.ownerMismatch(),
    ]) {
      gateway.readOverride = failure;
      container.invalidate(syncToCloudProvider);

      expect(await container.read(syncToCloudProvider.future), isFalse);
      expect(gateway.uploadAttempts, 0);
      expect(container.read(syncErrorMessageProvider), isNotEmpty);
      expect(await queue.queuedCount(), 0);
    }
  });

  test(
    'an unlinked full backup is a calm status, not a repeating sync error',
    () async {
      final _FixedOutcomeSyncService service = _FixedOutcomeSyncService(
        BackupService(
          taskRepository: repository,
          profileStorage: profileStorage,
          prefs: prefs,
        ),
        gateway,
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          hiveStoreProvider.overrideWithValue(hiveStore),
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('test-user'),
          ),
          cloudSyncCapabilityProvider.overrideWithValue(true),
          offlineSyncQueueProvider.overrideWithValue(
            OfflineSyncQueueService(
              HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
              accountId: 'test-user',
              enforceAccountBinding: true,
            ),
          ),
          syncServiceProvider.overrideWithValue(service),
        ],
      );

      Future<void> sync(CloudSyncOutcome outcome) async {
        service.outcome = outcome;
        container.invalidate(syncToCloudProvider);
        await container.read(syncToCloudProvider.future);
      }

      await sync(CloudSyncOutcome.fullBackupNotLinked);
      expect(container.read(syncErrorMessageProvider), isNull);
      expect(
        container.read(cloudBackupAttentionProvider),
        CloudBackupAttention.fullBackupNotLinked,
      );

      await sync(CloudSyncOutcome.conflict);
      expect(
        container.read(syncErrorMessageProvider),
        contains('replace that newer copy'),
      );
      expect(
        container.read(cloudBackupAttentionProvider),
        CloudBackupAttention.changedOnAnotherDevice,
      );

      await sync(CloudSyncOutcome.synced);
      expect(container.read(syncErrorMessageProvider), isNull);
      expect(
        container.read(cloudBackupAttentionProvider),
        CloudBackupAttention.none,
      );
    },
  );

  ProviderContainer keyContainer(
    SyncService service, {
    required bool cloudBackupOn,
  }) {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'test-user',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cloud_sync_enabled_v1.${scope.v2Namespace}': cloudBackupOn,
    });
    container.dispose();
    container = ProviderContainer(
      overrides: [
        hiveStoreProvider.overrideWithValue(hiveStore),
        accountStorageScopeProvider.overrideWithValue(scope),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        cloudSyncCapabilityProvider.overrideWithValue(true),
        syncServiceProvider.overrideWithValue(service),
      ],
    );
    return container;
  }

  test(
    'restoring a key needs Cloud Backup on, and a restored key counts as saved',
    () async {
      final String key = base64Encode(List<int>.filled(32, 5));
      final SyncService service = SyncService(
        backup: BackupService(
          taskRepository: repository,
          profileStorage: profileStorage,
          prefs: prefs,
        ),
        gateway: gateway,
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        expectedAccountId: 'test-user',
        currentAccountId: () => 'test-user',
        syncEnabled: true,
        restoreEnabled: true,
      );

      var keys = keyContainer(service, cloudBackupOn: false);
      expect(
        await keys.read(backupRecoveryKeyImportProvider)(key),
        RecoveryKeyImportOutcome.cloudBackupOff,
      );
      expect(await keys.read(recoveryKeySavedProvider.future), isFalse);
      expect(await keys.read(cloudBackupKeyStatusProvider.future), isNull);

      keys = keyContainer(service, cloudBackupOn: true);
      expect(await keys.read(recoveryKeySavedProvider.future), isFalse);
      expect(
        await keys.read(cloudBackupKeyStatusProvider.future),
        CloudBackupKeyCheck.noKeyOnDevice,
      );
      expect(
        await keys.read(backupRecoveryKeyImportProvider)(key),
        RecoveryKeyImportOutcome.installedUnverified,
      );
      expect(await keys.read(recoveryKeySavedProvider.future), isTrue);
      expect(
        await keys.read(cloudBackupKeyStatusProvider.future),
        CloudBackupKeyCheck.noEncryptedCloudBackup,
      );
    },
  );

  test(
    'discarding refreshes the key status and clears backup attention',
    () async {
      final _DiscardingSyncService service = _DiscardingSyncService(
        BackupService(
          taskRepository: repository,
          profileStorage: profileStorage,
          prefs: prefs,
        ),
        gateway,
      );
      var keys = keyContainer(service, cloudBackupOn: false);
      expect(
        await keys.read(cloudBackupDiscardProvider)(),
        CloudBackupDiscardOutcome.unavailable,
      );
      expect(service.discards, 0);

      keys = keyContainer(service, cloudBackupOn: true);
      expect(
        await keys.read(cloudBackupKeyStatusProvider.future),
        CloudBackupKeyCheck.doesNotMatch,
      );
      keys
          .read(cloudBackupAttentionProvider.notifier)
          .set(CloudBackupAttention.changedOnAnotherDevice);

      expect(
        await keys.read(cloudBackupDiscardProvider)(),
        CloudBackupDiscardOutcome.discarded,
      );
      expect(service.discards, 1);
      expect(
        await keys.read(cloudBackupKeyStatusProvider.future),
        CloudBackupKeyCheck.noEncryptedCloudBackup,
      );
      expect(
        keys.read(cloudBackupAttentionProvider),
        CloudBackupAttention.none,
      );
    },
  );

  test(
    'replayOfflineQueueProvider replays queued sync action and clears queue on success',
    () async {
      gateway.uploadShouldAlwaysSucceed = true;
      final OfflineSyncQueueService queue = OfflineSyncQueueService(
        HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
        accountId: 'test-user',
        enforceAccountBinding: true,
      );
      await queue.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'sync_to_cloud',
        payload: const <String, dynamic>{},
      );

      expect(await queue.queuedCount(), 1);

      final int processed = await container.read(
        replayOfflineQueueProvider.future,
      );
      expect(processed, 1);

      expect(await queue.queuedCount(), 0);
      expect(gateway.uploadAttempts, greaterThanOrEqualTo(1));
    },
  );

  test(
    'replayOfflineQueueProvider keeps unknown action items queued',
    () async {
      final OfflineSyncQueueService queue = OfflineSyncQueueService(
        HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
        accountId: 'test-user',
        enforceAccountBinding: true,
      );
      await queue.enqueue(
        actionType: 'unknown_action',
        dedupeKey: 'unknown_action',
        payload: const <String, dynamic>{'sample': true},
      );

      expect(await queue.queuedCount(), 1);

      final int processed = await container.read(
        replayOfflineQueueProvider.future,
      );
      expect(processed, 1);

      final int queuedAfterReplay = await queue.queuedCount();
      expect(queuedAfterReplay, 1);
    },
  );
}

class _FixedOutcomeSyncService extends SyncService {
  _FixedOutcomeSyncService(BackupService backup, CloudBackupGateway gateway)
    : super(
        backup: backup,
        gateway: gateway,
        expectedAccountId: 'test-user',
        currentAccountId: () => 'test-user',
        syncEnabled: true,
        restoreEnabled: true,
      );

  CloudSyncOutcome outcome = CloudSyncOutcome.synced;

  @override
  Future<CloudSyncOutcome> syncDeltaOutcome() async => outcome;
}

class _DiscardingSyncService extends SyncService {
  _DiscardingSyncService(BackupService backup, CloudBackupGateway gateway)
    : super(
        backup: backup,
        gateway: gateway,
        expectedAccountId: 'test-user',
        currentAccountId: () => 'test-user',
        syncEnabled: true,
        restoreEnabled: true,
      );

  int discards = 0;
  CloudBackupKeyCheck check = CloudBackupKeyCheck.doesNotMatch;

  @override
  Future<CloudBackupKeyCheck> checkCloudBackupKey({
    String? recoveryKey,
  }) async => check;

  @override
  Future<CloudBackupDiscardOutcome> discardUnreadableCloudBackup() async {
    discards += 1;
    check = CloudBackupKeyCheck.noEncryptedCloudBackup;
    return CloudBackupDiscardOutcome.discarded;
  }
}

class _SequencedCloudBackupGateway implements CloudBackupGateway {
  _SequencedCloudBackupGateway(this._uploadOutcomes);

  final List<bool> _uploadOutcomes;
  bool uploadShouldAlwaysSucceed = false;
  int uploadAttempts = 0;
  int revision = 0;
  Map<String, dynamic> fullBackup = <String, dynamic>{};
  CloudBackupReadResult? readOverride;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    return readOverride ??
        (fullBackup.isEmpty
            ? const CloudBackupReadResult.notFound()
            : CloudBackupReadResult.found(
                fullBackup,
                revision: revision == 0 ? 1 : revision,
              ));
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    final int currentRevision = fullBackup.isEmpty
        ? 0
        : (revision == 0 ? 1 : revision);
    if (currentRevision != expectedRevision) {
      return CloudBackupWriteResult.conflict(currentRevision);
    }
    uploadAttempts += 1;
    final bool outcome =
        uploadShouldAlwaysSucceed ||
        uploadAttempts > _uploadOutcomes.length ||
        _uploadOutcomes[uploadAttempts - 1];
    if (!outcome) return const CloudBackupWriteResult.unavailable();
    revision = expectedRevision + 1;
    fullBackup = backup;
    return CloudBackupWriteResult.written(revision);
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.notFound();

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
    uploadAttempts += 1;
    if (uploadShouldAlwaysSucceed) {
      fullBackup = backup;
      return true;
    }
    final bool outcome = uploadAttempts <= _uploadOutcomes.length
        ? _uploadOutcomes[uploadAttempts - 1]
        : true;
    if (outcome) {
      fullBackup = backup;
    }
    return outcome;
  }

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async {
    return true;
  }
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}

class _TestHiveStore implements HiveStore {
  @override
  Future<void> clearBox(String key) async {
    final Box<String> box = await openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }

  @override
  Box<T> box<T>(String key) {
    return Hive.box<T>(key);
  }

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) {
    return Hive.isBoxOpen(key);
  }

  @override
  Future<Box<T>> openBox<T>(String key) {
    if (Hive.isBoxOpen(key)) {
      return Future<Box<T>>.value(Hive.box<T>(key));
    }
    return Hive.openBox<T>(key);
  }
}
