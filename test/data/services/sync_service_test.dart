import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/cloud_backup_status_store.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  late _MemoryTaskRepository repository;
  late BackupService backupService;
  late _MemoryCloudBackupGateway gateway;
  late SyncService syncService;
  late Directory hiveDirectory;
  late HiveStorage<String> profileStorage;
  late SharedPrefsStorage prefs;
  late KeyedMutationCoordinator mutationCoordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_sync_test_',
    );
    Hive.init(hiveDirectory.path);
    repository = _MemoryTaskRepository();
    profileStorage = HiveStorage<String>('profile_box', hive: _TestHiveStore());
    prefs = SharedPrefsStorage(await SharedPreferences.getInstance());
    mutationCoordinator = KeyedMutationCoordinator();
    backupService = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: prefs,
      mutationCoordinator: mutationCoordinator,
    );
    gateway = _MemoryCloudBackupGateway();
    syncService = SyncService(
      backup: backupService,
      gateway: gateway,
      syncEnabled: true,
      restoreEnabled: true,
    );
  });

  tearDown(() async {
    await profileStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('syncToCloud uploads the full backup payload', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Upload me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );

    final bool success = await syncService.syncToCloud();
    final Map<String, dynamic> uploadedTask =
        ((gateway.fullBackup?['tasks'] as List<dynamic>).single
                as Map<dynamic, dynamic>)
            .map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            );

    expect(success, isTrue);
    expect(uploadedTask['id'], 'task-1');
  });

  test(
    'long recurring series stays valid through cloud backup and restore',
    () async {
      final String seriesId = List<String>.filled(20, 'series-root').join('-');
      TaskEntity current = TaskEntity(
        id: seriesId,
        title: 'Long-lived recurring task',
        createdAt: DateTime.utc(2026, 1, 1),
        scheduledFor: DateTime.utc(2026, 1, 1, 9),
        occurrenceKey: 'slot-0',
        recurrenceRule: RecurrenceRule.daily,
      );
      for (int index = 0; index < 120; index++) {
        final DateTime completedAt = DateTime.utc(2026, 1, 1 + index, 10);
        await repository.saveTask(
          current.copyWith(isCompleted: true, completedAt: completedAt),
        );
        current = current.copyWith(
          id: TaskEntity.recurringSuccessorId(
            seriesId: seriesId,
            occurrenceKey: 'slot-$index',
          ),
          createdAt: completedAt,
          updatedAt: completedAt,
          isCompleted: false,
          clearCompletedAt: true,
          scheduledFor: DateTime.utc(2026, 1, 2 + index, 9),
          occurrenceKey: 'slot-${index + 1}',
          recurrenceSeriesId: seriesId,
        );
      }
      await repository.saveTask(current);

      expect(await syncService.syncToCloud(), isTrue);
      repository.tasks.clear();
      expect(
        await syncService.restoreFromCloud(),
        CloudRestoreOutcome.restored,
      );

      final List<TaskEntity> restored = await repository.getAllTasks();
      expect(restored, hasLength(121));
      expect(
        restored.every((TaskEntity task) => task.id.length <= 256),
        isTrue,
      );
      expect(
        restored
            .where((TaskEntity task) => task.id != seriesId)
            .every((TaskEntity task) => task.recurrenceSeriesId == seriesId),
        isTrue,
      );
    },
  );

  test(
    'encrypted cloud backup round-trips only with the retained device key',
    () async {
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final SyncService encryptedService = SyncService(
        backup: backupService,
        gateway: gateway,
        secureStore: secureStore,
        syncEnabled: true,
        restoreEnabled: true,
      );
      await repository.saveTask(
        TaskEntity(
          id: 'encrypted-task',
          title: 'Protect this payload',
          createdAt: DateTime.utc(2026, 8, 19),
        ),
      );

      expect(await encryptedService.syncToCloud(), isTrue);
      expect(
        gateway.fullBackup,
        containsPair('format', 'chronospark_backup_aes256_gcm_v2'),
      );
      expect(gateway.fullBackup?['ciphertext'], isA<String>());
      expect(gateway.fullBackup, isNot(contains('tasks')));

      repository.tasks.clear();
      expect(
        await encryptedService.restoreFromCloud(),
        CloudRestoreOutcome.restored,
      );
      expect((await repository.getAllTasks()).single.id, 'encrypted-task');
    },
  );

  test(
    'migrates a valid legacy plaintext backup before restoring it',
    () async {
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final SyncService encryptedService = SyncService(
        backup: backupService,
        gateway: gateway,
        secureStore: secureStore,
        syncEnabled: true,
        restoreEnabled: true,
      );
      gateway.fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy-cloud-task',
            'title': 'Legacy cloud task',
            'createdAt': '2026-07-05T08:00:00.000Z',
          },
        ],
      );

      expect(
        await encryptedService.restoreFromCloud(),
        CloudRestoreOutcome.restored,
      );
      expect(
        gateway.fullBackup,
        containsPair('format', 'chronospark_backup_aes256_gcm_v2'),
      );
      expect((await repository.getAllTasks()).single.id, 'legacy-cloud-task');
    },
  );

  test(
    'verifies encrypted CAS migration before deleting legacy plaintext',
    () async {
      final _LegacyMigrationCleanupGateway migrationGateway =
          _LegacyMigrationCleanupGateway(
            _fullCloudBackup(
              tasks: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'verified-legacy-task',
                  'title': 'Verified legacy task',
                  'createdAt': '2026-07-05T08:00:00.000Z',
                },
              ],
            ),
          );
      final SyncService encryptedService = SyncService(
        backup: backupService,
        gateway: migrationGateway,
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        syncEnabled: true,
        restoreEnabled: true,
      );

      expect(
        await encryptedService.restoreFromCloud(),
        CloudRestoreOutcome.restored,
      );
      expect(migrationGateway.events, <String>[
        'read-legacy',
        'write-cas',
        'read-cas',
        'delete-legacy-full-backup',
      ]);
      expect(
        migrationGateway.casPayload,
        containsPair('format', 'chronospark_backup_aes256_gcm_v2'),
      );
      expect(
        (await repository.getAllTasks()).single.id,
        'verified-legacy-task',
      );
    },
  );

  test(
    'restores verified CAS but reports legacy cleanup pending on delete failure',
    () async {
      final _LegacyMigrationCleanupGateway migrationGateway =
          _LegacyMigrationCleanupGateway(
            _fullCloudBackup(
              tasks: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'cleanup-pending-task',
                  'title': 'Cleanup pending task',
                  'createdAt': '2026-07-05T08:00:00.000Z',
                },
              ],
            ),
            cleanupStatus: LegacyFullBackupCleanupStatus.unavailable,
          );
      final SyncService encryptedService = SyncService(
        backup: backupService,
        gateway: migrationGateway,
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        syncEnabled: true,
        restoreEnabled: true,
      );

      expect(
        await encryptedService.restoreFromCloud(),
        CloudRestoreOutcome.restoredLegacyCleanupPending,
      );
      expect(
        migrationGateway.casPayload,
        containsPair('format', 'chronospark_backup_aes256_gcm_v2'),
      );
      expect(
        (await repository.getAllTasks()).single.id,
        'cleanup-pending-task',
      );
    },
  );

  test('cleans stale legacy storage after an earlier CAS migration', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final Map<String, dynamic> plaintext = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'previously-migrated-task',
          'title': 'Previously migrated task',
          'createdAt': '2026-07-05T08:00:00.000Z',
        },
      ],
    );
    final Map<String, dynamic> encrypted = await BackupCipher(
      secureStore,
    ).encryptPayload(plaintext);
    final _LegacyMigrationCleanupGateway migrationGateway =
        _LegacyMigrationCleanupGateway(plaintext, initialCasPayload: encrypted);
    final SyncService encryptedService = SyncService(
      backup: backupService,
      gateway: migrationGateway,
      secureStore: secureStore,
      syncEnabled: true,
      restoreEnabled: true,
    );

    expect(
      await encryptedService.restoreFromCloud(),
      CloudRestoreOutcome.restored,
    );
    expect(migrationGateway.events, <String>[
      'read-cas',
      'delete-legacy-full-backup',
    ]);
    expect(
      (await repository.getAllTasks()).single.id,
      'previously-migrated-task',
    );
  });

  test('does not delete legacy plaintext when CAS readback differs', () async {
    final _LegacyMigrationCleanupGateway migrationGateway =
        _LegacyMigrationCleanupGateway(
          _fullCloudBackup(
            tasks: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'unverified-task',
                'title': 'Unverified task',
                'createdAt': '2026-07-05T08:00:00.000Z',
              },
            ],
          ),
          returnMismatchedReadback: true,
        );
    final SyncService encryptedService = SyncService(
      backup: backupService,
      gateway: migrationGateway,
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      syncEnabled: true,
      restoreEnabled: true,
    );

    expect(
      await encryptedService.restoreFromCloud(),
      CloudRestoreOutcome.migrationFailed,
    );
    expect(migrationGateway.events, <String>[
      'read-legacy',
      'write-cas',
      'read-cas',
    ]);
    expect(await repository.getAllTasks(), isEmpty);
  });

  test(
    'refuses a legacy plaintext restore when migration upload fails',
    () async {
      final SyncService encryptedService = SyncService(
        backup: backupService,
        gateway: gateway,
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        syncEnabled: true,
        restoreEnabled: true,
      );
      gateway
        ..fullBackup = _fullCloudBackup(
          tasks: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'legacy-cloud-task',
              'title': 'Legacy cloud task',
              'createdAt': '2026-07-05T08:00:00.000Z',
            },
          ],
        )
        ..uploadShouldFail = true;

      expect(
        await encryptedService.restoreFromCloud(),
        CloudRestoreOutcome.migrationFailed,
      );
      expect(await repository.getAllTasks(), isEmpty);
    },
  );

  test('encrypts the first delta upload when cloud storage is empty', () async {
    final SyncService encryptedService = SyncService(
      backup: backupService,
      gateway: gateway,
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      syncEnabled: true,
      restoreEnabled: true,
    );
    await repository.saveTask(
      TaskEntity(
        id: 'first-encrypted-delta',
        title: 'Protect first upload',
        createdAt: DateTime.utc(2026, 8, 20),
      ),
    );

    expect(await encryptedService.syncDelta(), isTrue);
    expect(
      gateway.fullBackup,
      containsPair('format', 'chronospark_backup_aes256_gcm_v2'),
    );
    expect(gateway.fullBackup, isNot(contains('tasks')));
  });

  test('restoreFromCloud reports when cloud backup is absent', () async {
    final CloudRestoreOutcome restored = await syncService.restoreFromCloud();

    expect(restored, CloudRestoreOutcome.notFound);
  });

  test('default service cannot read or write cloud data directly', () async {
    final SyncService contained = SyncService(
      backup: backupService,
      gateway: gateway,
    );
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'must-not-restore',
          'title': 'Contained',
          'createdAt': '2026-08-29T00:00:00.000Z',
        },
      ],
    );

    expect(await contained.syncToCloud(), isFalse);
    expect(await contained.syncDelta(), isFalse);
    expect(await contained.syncTasksOnly(), isFalse);
    expect(await contained.restoreFromCloud(), CloudRestoreOutcome.disabled);
    expect(await contained.restoreTasksOnly(), isFalse);
    expect(await repository.getAllTasks(), isEmpty);
  });

  test('restoreFromCloud restores tasks profile and settings', () async {
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cloud-1',
          'title': 'From cloud',
          'createdAt': '2026-07-05T08:00:00.000Z',
        },
      ],
      profile: <String, dynamic>{'name': 'Cloud User'},
      settings: <String, dynamic>{
        'cloud_sync_enabled_v1': false,
        'reflection_reminder_time': '20:00',
      },
    );

    final CloudRestoreOutcome restored = await syncService.restoreFromCloud();

    expect(restored, CloudRestoreOutcome.restored);
    expect((await repository.getAllTasks()).single.id, 'cloud-1');
    expect(
      profileStorage.get('profile_state'),
      jsonEncode(<String, dynamic>{'name': 'Cloud User'}),
    );
    expect(prefs.getBool('cloud_sync_enabled_v1'), isFalse);
    expect(prefs.getString('reflection_reminder_time'), '20:00');
  });

  test('syncDelta uploads local backup when cloud backup is empty', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'local-1',
        title: 'Local backup',
        createdAt: DateTime.utc(2026, 7, 5, 9),
      ),
    );

    final bool synced = await syncService.syncDelta();
    final Map<String, dynamic> uploadedTask =
        ((gateway.fullBackup?['tasks'] as List<dynamic>).single
                as Map<dynamic, dynamic>)
            .map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            );

    expect(synced, isTrue);
    expect(uploadedTask['id'], 'local-1');
  });

  test(
    'syncDelta does not upload after the signed-in account changes',
    () async {
      String currentAccount = 'user-1';
      gateway.onDownloadBackup = () {
        currentAccount = 'user-2';
      };
      final SyncService guarded = SyncService(
        backup: backupService,
        gateway: gateway,
        expectedAccountId: 'user-1',
        currentAccountId: () => currentAccount,
        syncEnabled: true,
        restoreEnabled: true,
      );

      expect(await guarded.syncDeltaOutcome(), CloudSyncOutcome.accountChanged);
      expect(gateway.uploadBackupCalls, 0);
    },
  );

  test(
    'syncDelta does not report success after account turnover in upload',
    () async {
      String currentAccount = 'user-1';
      gateway.onUploadBackup = () {
        currentAccount = 'user-2';
      };
      final SyncService guarded = SyncService(
        backup: backupService,
        gateway: gateway,
        expectedAccountId: 'user-1',
        currentAccountId: () => currentAccount,
        syncEnabled: true,
        restoreEnabled: true,
      );

      expect(await guarded.syncDeltaOutcome(), CloudSyncOutcome.accountChanged);
      expect(gateway.uploadBackupCalls, 1);
    },
  );

  test('syncDelta preserves a local edit made during cloud upload', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'before-sync',
        title: 'Before sync',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    gateway.beforeCompareAndSwap = () {
      return runAccountStorageMutation(() async {
        await repository.saveTask(
          TaskEntity(
            id: 'during-sync',
            title: 'Created during sync',
            createdAt: DateTime.utc(2026, 7, 6),
          ),
        );
      }, coordinator: mutationCoordinator);
    };

    final CloudSyncOutcome outcome = await syncService.syncDeltaOutcome();

    expect(outcome, CloudSyncOutcome.conflict);
    expect(
      (await repository.getAllTasks()).map((TaskEntity task) => task.id),
      containsAll(<String>['before-sync', 'during-sync']),
    );
  });

  test('syncDelta preserves a profile edit made during cloud upload', () async {
    final SecureStore profileStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await profileStore.writeString(
      'profile_state_v2',
      jsonEncode(<String, dynamic>{'name': 'Before sync'}),
    );
    final BackupService profileBackup = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: prefs,
      secureProfileStore: profileStore,
      mutationCoordinator: mutationCoordinator,
    );
    final SyncService profileSync = SyncService(
      backup: profileBackup,
      gateway: gateway,
      syncEnabled: true,
      restoreEnabled: true,
    );
    gateway.beforeCompareAndSwap = () {
      return runAccountStorageMutation(
        () => profileStore.writeString(
          'profile_state_v2',
          jsonEncode(<String, dynamic>{'name': 'Edited during sync'}),
        ),
        coordinator: mutationCoordinator,
      );
    };

    final CloudSyncOutcome outcome = await profileSync.syncDeltaOutcome();
    final Map<String, dynamic> storedProfile =
        jsonDecode((await profileStore.readString('profile_state_v2'))!)
            as Map<String, dynamic>;

    expect(outcome, CloudSyncOutcome.conflict);
    expect(storedProfile['name'], 'Edited during sync');
  });

  test('encrypted backup without a local key requires recovery', () async {
    final BackupCipher sourceCipher = BackupCipher(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );
    gateway.fullBackup = await sourceCipher.encryptPayload(
      _fullCloudBackup(tasks: <Map<String, dynamic>>[]),
    );
    final SyncService replacementDevice = SyncService(
      backup: backupService,
      gateway: gateway,
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      syncEnabled: true,
      restoreEnabled: true,
    );

    expect(
      await replacementDevice.restoreFromCloud(),
      CloudRestoreOutcome.recoveryKeyRequired,
    );
    expect(
      await replacementDevice.syncDeltaOutcome(),
      CloudSyncOutcome.recoveryKeyRequired,
    );
    expect(gateway.uploadBackupCalls, 0);
  });

  test('syncDelta never seeds cloud after an ambiguous read failure', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'local-1',
        title: 'Keep local',
        createdAt: DateTime.utc(2026, 7, 5, 9),
      ),
    );
    for (final CloudBackupReadResult failure in <CloudBackupReadResult>[
      const CloudBackupReadResult.unavailable(),
      const CloudBackupReadResult.malformed(),
      const CloudBackupReadResult.ownerMismatch(),
    ]) {
      gateway
        ..fullReadOverride = failure
        ..uploadBackupCalls = 0;

      expect(await syncService.syncDelta(), isFalse);
      expect(gateway.uploadBackupCalls, 0);
    }
  });

  test('concurrent writers surface a conflict without overwriting', () async {
    final _ConcurrentCasGateway concurrentGateway = _ConcurrentCasGateway(
      _fullCloudBackup(tasks: <Map<String, dynamic>>[]),
    );
    final SyncService first = SyncService(
      backup: backupService,
      gateway: concurrentGateway,
      syncEnabled: true,
      restoreEnabled: true,
    );
    final SyncService second = SyncService(
      backup: backupService,
      gateway: concurrentGateway,
      syncEnabled: true,
      restoreEnabled: true,
    );

    final List<CloudSyncOutcome> outcomes = await Future.wait(
      <Future<CloudSyncOutcome>>[
        first.syncDeltaOutcome(),
        second.syncDeltaOutcome(),
      ],
    );

    expect(outcomes, contains(CloudSyncOutcome.synced));
    expect(outcomes, contains(CloudSyncOutcome.conflict));
    expect(concurrentGateway.revision, 2);
    expect(concurrentGateway.successfulWrites, 1);
  });

  test('restore stops before local commit when the account changes', () async {
    String currentAccount = 'user-1';
    gateway
      ..fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'other-account-task',
            'title': 'Must not cross accounts',
            'createdAt': '2026-08-29T00:00:00.000Z',
          },
        ],
      )
      ..onDownloadBackup = () {
        currentAccount = 'user-2';
      };
    final SyncService guarded = SyncService(
      backup: backupService,
      gateway: gateway,
      expectedAccountId: 'user-1',
      currentAccountId: () => currentAccount,
      syncEnabled: true,
      restoreEnabled: true,
    );

    expect(
      await guarded.restoreFromCloud(),
      CloudRestoreOutcome.accountChanged,
    );
    expect(await repository.getAllTasks(), isEmpty);
  });

  test(
    'restore rolls back when the account changes during local writes',
    () async {
      String currentAccount = 'user-1';
      gateway.fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'other-account-task',
            'title': 'Must roll back',
            'createdAt': '2026-08-29T00:00:00.000Z',
          },
        ],
      );
      repository.onSave = (TaskEntity task) {
        if (task.id == 'other-account-task') currentAccount = 'user-2';
      };
      final SyncService guarded = SyncService(
        backup: backupService,
        gateway: gateway,
        expectedAccountId: 'user-1',
        currentAccountId: () => currentAccount,
        syncEnabled: true,
        restoreEnabled: true,
      );

      expect(
        await guarded.restoreFromCloud(),
        CloudRestoreOutcome.accountChanged,
      );
      expect(await repository.getAllTasks(), isEmpty);
    },
  );

  test(
    'syncDelta merges newer local task over older cloud task and restores merged data',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'shared',
          title: 'Local newer',
          createdAt: DateTime.utc(2026, 7, 5, 12),
        ),
      );
      gateway.fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'shared',
            'title': 'Cloud older',
            'createdAt': '2026-07-05T08:00:00.000Z',
          },
          <String, dynamic>{
            'id': 'cloud-only',
            'title': 'Cloud task',
            'createdAt': '2026-07-05T07:00:00.000Z',
          },
        ],
        settings: <String, dynamic>{'daily_planning_reminder_time': '19:30'},
      );

      final bool synced = await syncService.syncDelta();

      expect(synced, isTrue);
      final List<dynamic> tasks = gateway.fullBackup?['tasks'] as List<dynamic>;
      final List<Map<String, dynamic>> normalizedTasks = tasks
          .cast<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> task) => task.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          )
          .toList(growable: false);
      expect(tasks, hasLength(2));
      expect(
        normalizedTasks.any(
          (Map<String, dynamic> task) => task['title'] == 'Local newer',
        ),
        isTrue,
      );
      expect(
        normalizedTasks.any(
          (Map<String, dynamic> task) => task['id'] == 'cloud-only',
        ),
        isTrue,
      );
      expect((await repository.getAllTasks()).length, 2);
    },
  );

  test('syncDelta returns false when merged upload fails', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Local only',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    gateway.fullBackup = _fullCloudBackup(tasks: <Map<String, dynamic>>[]);
    gateway.uploadShouldFail = true;

    final bool synced = await syncService.syncDelta();

    expect(synced, isFalse);
  });

  test('syncDelta keeps cloud task when it is newer than local task', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'shared',
        title: 'Local older',
        createdAt: DateTime.utc(2026, 7, 5, 8),
      ),
    );
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Cloud newer',
          'updatedAt': '2026-07-05T12:00:00.000Z',
          'createdAt': '2026-07-05T07:00:00.000Z',
        },
      ],
    );

    final bool synced = await syncService.syncDelta();
    final Map<String, dynamic> mergedTask =
        ((gateway.fullBackup?['tasks'] as List<dynamic>).single
                as Map<dynamic, dynamic>)
            .map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            );

    expect(synced, isTrue);
    expect(mergedTask['title'], 'Cloud newer');
  });

  // Conflict resolution had no coverage for the ambiguous cases, which are the
  // ones that lose user data. These pin the current rules so a change to them
  // is visible rather than silent.

  List<Map<String, dynamic>> mergedTasks() {
    return (gateway.fullBackup?['tasks'] as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> task) => task.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }

  test('syncDelta breaks an exact timestamp tie in favour of local', () async {
    // Two devices editing the same task within the same clock tick is rare but
    // reachable, and an undefined winner here means a silent lost edit.
    await repository.saveTask(
      TaskEntity(
        id: 'shared',
        title: 'Local edit',
        createdAt: DateTime.utc(2026, 7, 5, 10),
      ),
    );
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Cloud edit',
          'createdAt': '2026-07-05T10:00:00.000Z',
        },
      ],
    );

    expect(await syncService.syncDelta(), isTrue);
    expect(mergedTasks().single['title'], 'Local edit');
  });

  test('syncDelta keeps a task that exists only in the cloud', () async {
    // A task created on another device must survive a sync from this one.
    await repository.saveTask(
      TaskEntity(
        id: 'local-only',
        title: 'From this device',
        createdAt: DateTime.utc(2026, 7, 5, 9),
      ),
    );
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cloud-only',
          'title': 'From another device',
          'createdAt': '2026-07-05T09:00:00.000Z',
        },
      ],
    );

    expect(await syncService.syncDelta(), isTrue);
    expect(
      mergedTasks().map((Map<String, dynamic> task) => task['id']).toSet(),
      <String>{'local-only', 'cloud-only'},
    );
  });

  test(
    'syncDelta ranks a completed local task above an older cloud copy',
    () async {
      // _taskTimestamp prefers updatedAt, then completedAt, then createdAt.
      // This case protects compatibility with records that predate updatedAt.
      await repository.saveTask(
        TaskEntity(
          id: 'shared',
          title: 'Local completed later',
          createdAt: DateTime.utc(2026, 7, 1),
          isCompleted: true,
          completedAt: DateTime.utc(2026, 7, 9),
        ),
      );
      gateway.fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'shared',
            'title': 'Cloud created later, never completed',
            'createdAt': '2026-07-05T00:00:00.000Z',
          },
        ],
      );

      expect(await syncService.syncDelta(), isTrue);
      expect(mergedTasks().single['title'], 'Local completed later');
    },
  );

  test('syncDelta keeps a local edit with a newer updatedAt', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'shared',
        title: 'Locally renamed, never synced',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 6),
      ),
    );
    gateway.fullBackup = _fullCloudBackup(
      tasks: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Stale cloud title',
          'createdAt': '2026-07-05T00:00:00.000Z',
          'updatedAt': '2026-07-05T12:00:00.000Z',
        },
      ],
    );

    expect(await syncService.syncDelta(), isTrue);
    expect(mergedTasks().single['title'], 'Locally renamed, never synced');
    expect(mergedTasks().single['updatedAt'], '2026-07-06T00:00:00.000Z');
  });

  test(
    'syncDelta keeps a newer local deletion tombstone over a cloud task',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'deleted-here',
          title: 'Deleted on this device',
          createdAt: DateTime.utc(2026, 7, 5, 8),
          updatedAt: DateTime.utc(2026, 7, 5, 12),
          isCanceled: true,
        ),
      );
      gateway.fullBackup = _fullCloudBackup(
        tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'deleted-here',
            'title': 'Deleted on this device',
            'createdAt': '2026-07-05T09:00:00.000Z',
            'updatedAt': '2026-07-05T10:00:00.000Z',
          },
        ],
      );

      expect(await syncService.syncDelta(), isTrue);
      expect(mergedTasks().single['id'], 'deleted-here');
      expect(mergedTasks().single['isCanceled'], isTrue);
      expect((await repository.getAllTasks()).single.isCanceled, isTrue);
    },
  );

  test(
    'syncTasksOnly and restoreTasksOnly operate on task payloads only',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'task-1',
          title: 'Task only',
          createdAt: DateTime.utc(2026, 7, 5),
        ),
      );

      final bool uploaded = await syncService.syncTasksOnly();
      final Map<String, dynamic> uploadedTask =
          ((gateway.tasksBackup?['tasks'] as List<dynamic>).single
                  as Map<dynamic, dynamic>)
              .map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              );
      expect(uploaded, isTrue);
      expect(uploadedTask['id'], 'task-1');

      repository.tasks.clear();
      gateway.tasksBackup = <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'restored-task',
            'title': 'Restored only',
            'createdAt': '2026-07-05T08:00:00.000Z',
          },
        ],
      };

      final bool restored = await syncService.restoreTasksOnly();
      expect(restored, isTrue);
      expect((await repository.getAllTasks()).single.id, 'restored-task');
    },
  );

  test(
    'syncTasksOnly refuses to overwrite an existing remote payload',
    () async {
      gateway.tasksBackup = <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'remote-task',
            'title': 'Keep remote',
            'createdAt': '2026-07-05T08:00:00.000Z',
          },
        ],
      };
      await repository.saveTask(
        TaskEntity(
          id: 'local-task',
          title: 'Do not overwrite remote',
          createdAt: DateTime.utc(2026, 7, 5, 9),
        ),
      );

      expect(await syncService.syncTasksOnly(), isFalse);
      final List<dynamic> tasks =
          gateway.tasksBackup!['tasks'] as List<dynamic>;
      expect((tasks.single as Map<String, dynamic>)['id'], 'remote-task');
    },
  );

  test(
    'restoreTasksOnly returns false when cloud task payload is empty',
    () async {
      final bool restored = await syncService.restoreTasksOnly();

      expect(restored, isFalse);
    },
  );

  test(
    'local test cloud backup gateway stores and retrieves payloads',
    () async {
      final LocalTestCloudBackupGateway localGateway =
          LocalTestCloudBackupGateway(prefs);
      final Map<String, dynamic> backup = <String, dynamic>{'version': '3.0.0'};
      final Map<String, dynamic> tasks = <String, dynamic>{
        'tasks': <dynamic>[],
      };

      expect(await localGateway.uploadBackup(backup), isTrue);
      expect(await localGateway.uploadTasks(tasks), isTrue);
      expect((await localGateway.downloadBackup()).payload, backup);
      expect((await localGateway.downloadTasks()).payload, tasks);
    },
  );

  test(
    'unavailable cloud backup gateway always returns empty or false',
    () async {
      const UnavailableCloudBackupGateway gateway =
          UnavailableCloudBackupGateway();

      expect(await gateway.uploadBackup(<String, dynamic>{}), isFalse);
      expect(await gateway.uploadTasks(<String, dynamic>{}), isFalse);
      expect(
        (await gateway.downloadBackup()).status,
        CloudBackupReadStatus.unavailable,
      );
      expect(
        (await gateway.downloadTasks()).status,
        CloudBackupReadStatus.unavailable,
      );
      expect(
        (await gateway.compareAndSwapBackup(
          <String, dynamic>{},
          expectedRevision: 0,
        )).status,
        CloudBackupWriteStatus.unavailable,
      );
    },
  );

  test(
    'local cloud gateway rejects stale revisions and malformed payloads',
    () async {
      final LocalTestCloudBackupGateway localGateway =
          LocalTestCloudBackupGateway(prefs);
      final CloudBackupWriteResult first = await localGateway
          .compareAndSwapBackup(<String, dynamic>{
            'version': 1,
          }, expectedRevision: 0);
      expect(first.status, CloudBackupWriteStatus.written);
      expect(first.revision, 1);

      final CloudBackupWriteResult stale = await localGateway
          .compareAndSwapBackup(<String, dynamic>{
            'version': 2,
          }, expectedRevision: 0);
      expect(stale.status, CloudBackupWriteStatus.conflict);
      expect(stale.revision, 1);
      expect(
        await localGateway.uploadBackup(<String, dynamic>{'version': 2}),
        isTrue,
      );

      await prefs.setString('local_test_cloud_tasks', '{not-json');
      expect(
        (await localGateway.downloadTasks()).status,
        CloudBackupReadStatus.malformed,
      );
      await prefs.setString('local_test_cloud_tasks', '[]');
      expect(
        (await localGateway.downloadTasks()).status,
        CloudBackupReadStatus.malformed,
      );
    },
  );

  test(
    'restore and delta outcomes retain exact cloud failure categories',
    () async {
      final Map<CloudBackupReadResult, CloudRestoreOutcome> restoreCases =
          <CloudBackupReadResult, CloudRestoreOutcome>{
            const CloudBackupReadResult.unavailable():
                CloudRestoreOutcome.unavailable,
            const CloudBackupReadResult.malformed():
                CloudRestoreOutcome.malformed,
            const CloudBackupReadResult.ownerMismatch():
                CloudRestoreOutcome.ownerMismatch,
          };
      for (final MapEntry<CloudBackupReadResult, CloudRestoreOutcome> item
          in restoreCases.entries) {
        gateway.fullReadOverride = item.key;
        expect(await syncService.restoreFromCloud(), item.value);
      }

      final Map<CloudBackupReadResult, CloudSyncOutcome> syncCases =
          <CloudBackupReadResult, CloudSyncOutcome>{
            const CloudBackupReadResult.unavailable():
                CloudSyncOutcome.unavailable,
            const CloudBackupReadResult.malformed(): CloudSyncOutcome.malformed,
            const CloudBackupReadResult.ownerMismatch():
                CloudSyncOutcome.ownerMismatch,
          };
      for (final MapEntry<CloudBackupReadResult, CloudSyncOutcome> item
          in syncCases.entries) {
        gateway.fullReadOverride = item.key;
        expect(await syncService.syncDeltaOutcome(), item.value);
      }
    },
  );

  test(
    'write outcomes retain owner-mismatch and malformed categories',
    () async {
      gateway
        ..fullBackup = _fullCloudBackup(tasks: <Map<String, dynamic>>[])
        ..revision = 1
        ..writeOverride = const CloudBackupWriteResult.ownerMismatch();
      expect(
        await syncService.syncDeltaOutcome(),
        CloudSyncOutcome.ownerMismatch,
      );

      gateway.writeOverride = const CloudBackupWriteResult.malformed();
      expect(await syncService.syncDeltaOutcome(), CloudSyncOutcome.malformed);
    },
  );

  test(
    'default and Supabase wrappers fail closed without an authenticated owner',
    () async {
      final CloudBackupWriteResult defaultWrite = await _DefaultCasGateway()
          .compareAndSwapBackup(<String, dynamic>{}, expectedRevision: 0);
      expect(defaultWrite.status, CloudBackupWriteStatus.unavailable);

      final sb.SupabaseClient client = sb.SupabaseClient(
        'https://example.supabase.co',
        'public-anon-key',
      );
      addTearDown(client.dispose);
      final SupabaseCasCloudBackupGateway guarded =
          SupabaseCasCloudBackupGateway(
            client: client,
            expectedUserId: 'account-a',
          );
      expect(await guarded.uploadBackup(<String, dynamic>{}), isFalse);
      expect(
        (await guarded.compareAndSwapBackup(
          <String, dynamic>{},
          expectedRevision: 0,
        )).status,
        CloudBackupWriteStatus.ownerMismatch,
      );
      expect(
        (await guarded.downloadBackup()).status,
        CloudBackupReadStatus.ownerMismatch,
      );
      expect(
        (await guarded.downloadTasks()).status,
        CloudBackupReadStatus.ownerMismatch,
      );
      expect(await guarded.uploadTasks(<String, dynamic>{}), isFalse);
      expect(
        await guarded.deleteLegacyFullBackup(),
        LegacyFullBackupCleanupStatus.ownerMismatch,
      );
    },
  );

  group('recovery key check and import', () {
    final String otherKey = base64Encode(List<int>.filled(32, 9));
    late SecureStore originalKeys;
    late BackupCipher originalCipher;

    SyncService serviceWith(SecureStore keys, [CloudBackupGateway? cloud]) {
      return SyncService(
        backup: backupService,
        gateway: cloud ?? gateway,
        secureStore: keys,
        syncEnabled: true,
        restoreEnabled: true,
      );
    }

    Future<String?> storedKey(SecureStore keys) =>
        BackupCipher(keys).loadExistingRecoveryKey();

    setUp(() async {
      originalKeys = SecureStore(backend: InMemorySecureStoreBackend());
      originalCipher = BackupCipher(originalKeys);
      gateway.fullBackup = await originalCipher.encryptPayload(
        _fullCloudBackup(
          tasks: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'key-check-task',
              'title': 'Encrypted with the original key',
              'createdAt': '2026-08-29T12:00:00.000Z',
            },
          ],
        ),
      );
    });

    test(
      'checkCloudBackupKey reports whether a key opens the backup',
      () async {
        final SyncService service = serviceWith(originalKeys);

        expect(
          await service.checkCloudBackupKey(),
          CloudBackupKeyCheck.matches,
        );
        expect(
          await service.checkCloudBackupKey(recoveryKey: otherKey),
          CloudBackupKeyCheck.doesNotMatch,
        );
        expect(
          await serviceWith(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ).checkCloudBackupKey(),
          CloudBackupKeyCheck.noKeyOnDevice,
        );
        gateway.fullReadOverride = const CloudBackupReadResult.unavailable();
        expect(
          await service.checkCloudBackupKey(),
          CloudBackupKeyCheck.unavailable,
        );
        gateway.fullReadOverride = const CloudBackupReadResult.notFound();
        expect(
          await service.checkCloudBackupKey(),
          CloudBackupKeyCheck.noEncryptedCloudBackup,
        );
      },
    );

    test(
      'a key that does not open the backup leaves the stored key unchanged',
      () async {
        final String? original = await storedKey(originalKeys);
        final SyncService service = serviceWith(originalKeys);

        expect(
          await service.importRecoveryKey(otherKey),
          RecoveryKeyImportOutcome.doesNotMatch,
        );

        expect(await storedKey(originalKeys), original);
        expect(await service.restoreFromCloud(), CloudRestoreOutcome.restored);
      },
    );

    test('a matching key is installed on a replacement device', () async {
      final SecureStore replacementKeys = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final SyncService replacement = serviceWith(replacementKeys);
      expect(
        await replacement.restoreFromCloud(),
        CloudRestoreOutcome.recoveryKeyRequired,
      );

      expect(
        await replacement.importRecoveryKey(
          ' ${(await storedKey(originalKeys))!} ',
        ),
        RecoveryKeyImportOutcome.installed,
      );

      expect(await storedKey(replacementKeys), await storedKey(originalKeys));
      expect(
        await replacement.restoreFromCloud(),
        CloudRestoreOutcome.restored,
      );
    });

    test('an unreachable cloud backup refuses the import', () async {
      final String? original = await storedKey(originalKeys);
      gateway.fullReadOverride = const CloudBackupReadResult.unavailable();

      expect(
        await serviceWith(originalKeys).importRecoveryKey(otherKey),
        RecoveryKeyImportOutcome.cloudUnavailable,
      );
      expect(await storedKey(originalKeys), original);
    });

    test('a malformed key is rejected without touching storage', () async {
      final String? original = await storedKey(originalKeys);

      expect(
        await serviceWith(originalKeys).importRecoveryKey('not a key'),
        RecoveryKeyImportOutcome.invalidFormat,
      );
      expect(
        await serviceWith(originalKeys).importRecoveryKey('AA=='),
        RecoveryKeyImportOutcome.invalidFormat,
      );
      expect(await storedKey(originalKeys), original);
    });

    test(
      'with no cloud backup to test, the previous key stays recoverable',
      () async {
        final String? original = await storedKey(originalKeys);
        final Map<String, dynamic>? oldBackup = gateway.fullBackup;
        gateway.fullBackup = null;
        final SyncService service = serviceWith(originalKeys);

        expect(
          await service.importRecoveryKey(otherKey),
          RecoveryKeyImportOutcome.installedUnverified,
        );
        expect(await storedKey(originalKeys), otherKey);

        // A backup made with the previous key appears (for example from the
        // device that made it): it still opens, and the previous key returns.
        gateway.fullBackup = oldBackup;
        expect(await service.restoreFromCloud(), CloudRestoreOutcome.restored);
        expect(await storedKey(originalKeys), original);
      },
    );

    test(
      'a correct key on a damaged backup is reported as damaged, not as a wrong key',
      () async {
        // Encrypted with the right key, but not a valid backup inside.
        gateway.fullBackup = await originalCipher.encryptPayload(
          <String, dynamic>{'version': '3.0.0'},
        );
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.unreadable,
        );
        expect(
          await serviceWith(
            originalKeys,
          ).checkCloudBackupKey(recoveryKey: otherKey),
          CloudBackupKeyCheck.doesNotMatch,
        );

        final SecureStore replacementKeys = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        expect(
          await serviceWith(
            replacementKeys,
          ).importRecoveryKey((await storedKey(originalKeys))!),
          RecoveryKeyImportOutcome.backupUnreadable,
        );
        expect(await storedKey(replacementKeys), isNull);
      },
    );

    test('a cloud owner mismatch is reported as such on import', () async {
      final String? original = await storedKey(originalKeys);
      gateway.fullReadOverride = const CloudBackupReadResult.ownerMismatch();

      expect(
        await serviceWith(originalKeys).importRecoveryKey(otherKey),
        RecoveryKeyImportOutcome.ownerMismatch,
      );
      expect(await storedKey(originalKeys), original);
    });

    test(
      'a backup from a newer app version is reported as such, not as damaged',
      () async {
        gateway.fullBackup = await originalCipher
            .encryptPayload(<String, dynamic>{
              ..._fullCloudBackup(tasks: const <Map<String, dynamic>>[]),
              'version': '7.0.0',
            });
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.newerVersion,
        );
        final SecureStore replacementKeys = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        expect(
          await serviceWith(
            replacementKeys,
          ).importRecoveryKey((await storedKey(originalKeys))!),
          RecoveryKeyImportOutcome.newerVersion,
        );
        expect(await storedKey(replacementKeys), isNull);

        // A newer encryption format cannot be opened here at all.
        gateway.fullBackup = <String, dynamic>{
          'format': 'chronospark_backup_aes256_gcm_v3',
          'iv': 'AAAA',
          'ciphertext': 'AAAA',
        };
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.newerVersion,
        );
        // Content that no version could have written is still malformed.
        gateway.fullBackup = <String, dynamic>{'unexpected': true};
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.malformed,
        );
      },
    );

    test(
      'a row the gateway cannot parse is reported as unreadable, not offline',
      () async {
        gateway.fullReadOverride = const CloudBackupReadResult.malformed();
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.cloudBackupUnreadable,
        );
        expect(
          await serviceWith(originalKeys).importRecoveryKey(otherKey),
          RecoveryKeyImportOutcome.cloudBackupUnreadable,
        );
        // A junk row that only names a format is not a newer app's backup.
        gateway.fullReadOverride = null;
        gateway.fullBackup = <String, dynamic>{'format': 'something-else'};
        expect(
          await serviceWith(originalKeys).checkCloudBackupKey(),
          CloudBackupKeyCheck.malformed,
        );
      },
    );

    test('finds whether an encrypted cloud backup exists, read-only', () async {
      final SecureStore noKeys = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final SyncService service = serviceWith(noKeys);
      expect(
        await service.findCloudBackup(),
        CloudBackupPresence.encryptedBackup,
      );
      gateway.fullBackup = <String, dynamic>{
        'format': 'chronospark_backup_aes256_gcm_v3',
        'iv': 'AAAA',
        'ciphertext': 'AAAA',
      };
      expect(
        await service.findCloudBackup(),
        CloudBackupPresence.encryptedBackup,
      );
      gateway.fullBackup = null;
      expect(
        await service.findCloudBackup(),
        CloudBackupPresence.noEncryptedBackup,
      );
      gateway.fullReadOverride = const CloudBackupReadResult.unavailable();
      expect(await service.findCloudBackup(), CloudBackupPresence.unknown);
      gateway.fullReadOverride = const CloudBackupReadResult.malformed();
      expect(
        await service.findCloudBackup(),
        CloudBackupPresence.cloudBackupUnreadable,
      );
      expect(await storedKey(noKeys), isNull);
      expect(gateway.uploadBackupCalls, 0);
    });
  });

  group('discarding a cloud backup this device cannot read', () {
    final String deviceKey = base64Encode(List<int>.filled(32, 7));
    late SecureStore originalKeys;
    late SecureStore deviceKeys;
    late CloudBackupStatusStore status;

    SyncService serviceWith(SecureStore keys) => SyncService(
      backup: backupService,
      gateway: gateway,
      secureStore: keys,
      statusStore: status,
      syncEnabled: true,
      restoreEnabled: true,
    );

    setUp(() async {
      originalKeys = SecureStore(backend: InMemorySecureStoreBackend());
      gateway.fullBackup = await BackupCipher(
        originalKeys,
      ).encryptPayload(_fullCloudBackup(tasks: const <Map<String, dynamic>>[]));
      gateway.revision = 3;
      deviceKeys = SecureStore(backend: InMemorySecureStoreBackend());
      await BackupCipher(deviceKeys).installVerifiedRecoveryKey(deviceKey);
      status = CloudBackupStatusStore(prefs);
      await status.write(const CloudBackupStatus(revision: 2));
    });

    test('a backup this device can read is never discarded', () async {
      expect(
        await serviceWith(originalKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.readable,
      );
      expect(gateway.deleteCalls, 0);
      expect(gateway.fullBackup, isNotNull);
    });

    test(
      'an unreadable backup is deleted at the revision read, and backup starts over',
      () async {
        final SyncService device = serviceWith(deviceKeys);

        expect(
          await device.discardUnreadableCloudBackup(),
          CloudBackupDiscardOutcome.discarded,
        );
        expect(gateway.deletedRevisions, <int>[3]);
        expect(gateway.fullBackup, isNull);
        expect(status.read(), isNull);

        expect(await device.syncDeltaOutcome(), CloudSyncOutcome.synced);
        expect(gateway.revision, 1);
        expect(await device.checkCloudBackupKey(), CloudBackupKeyCheck.matches);
        expect(
          await BackupCipher(deviceKeys).loadExistingRecoveryKey(),
          deviceKey,
        );
      },
    );

    test('a backup replaced meanwhile is not deleted', () async {
      gateway.beforeDelete = () async => gateway.revision = 4;

      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.changed,
      );
      expect(gateway.fullBackup, isNotNull);
      expect(status.read()!.revision, 2);
    });

    test('a delete the server refuses changes nothing', () async {
      gateway.refuseDelete = true;

      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.refused,
      );
      expect(gateway.fullBackup, isNotNull);
      expect(status.read()!.revision, 2);
      expect(
        await BackupCipher(deviceKeys).loadExistingRecoveryKey(),
        deviceKey,
      );
    });

    test('needs a key on this device and a backup to discard', () async {
      expect(
        await serviceWith(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.noKeyOnDevice,
      );
      gateway.fullReadOverride = const CloudBackupReadResult.unavailable();
      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.unavailable,
      );
      gateway.fullReadOverride = null;
      gateway.fullBackup = null;
      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.nothingToDiscard,
      );
      expect(gateway.deleteCalls, 0);
    });

    test('a backup made by a newer app version is never discarded', () async {
      // Readable by this device's key, but a version this build does not know.
      final String? device = await BackupCipher(
        deviceKeys,
      ).loadExistingRecoveryKey();
      expect(device, deviceKey);
      gateway.fullBackup = await BackupCipher(deviceKeys)
          .encryptPayload(<String, dynamic>{
            ..._fullCloudBackup(tasks: const <Map<String, dynamic>>[]),
            'version': '7.0.0',
          });
      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.newerVersion,
      );
      // The same on the device whose key made it.
      gateway.fullBackup = await BackupCipher(originalKeys)
          .encryptPayload(<String, dynamic>{
            ..._fullCloudBackup(tasks: const <Map<String, dynamic>>[]),
            'version': '7.0.0',
          });
      expect(
        await serviceWith(originalKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.newerVersion,
      );
      // A newer encryption format: nothing here can decide it is unreadable.
      gateway.fullBackup = <String, dynamic>{
        'format': 'chronospark_backup_aes256_gcm_v3',
        'iv': 'AAAA',
        'ciphertext': 'AAAA',
      };
      expect(
        await serviceWith(deviceKeys).discardUnreadableCloudBackup(),
        CloudBackupDiscardOutcome.newerVersion,
      );
      expect(gateway.deleteCalls, 0);
      expect(gateway.fullBackup, isNotNull);
    });
  });

  group('starting over when the saved key is lost', () {
    late SecureStore originalKeys;
    late SecureStore noKeys;
    late CloudBackupStatusStore status;

    SyncService serviceWith(SecureStore keys) => SyncService(
      backup: backupService,
      gateway: gateway,
      secureStore: keys,
      statusStore: status,
      syncEnabled: true,
      restoreEnabled: true,
    );

    setUp(() async {
      originalKeys = SecureStore(backend: InMemorySecureStoreBackend());
      gateway.fullBackup = await BackupCipher(
        originalKeys,
      ).encryptPayload(_fullCloudBackup(tasks: const <Map<String, dynamic>>[]));
      gateway.revision = 5;
      noKeys = SecureStore(backend: InMemorySecureStoreBackend());
      status = CloudBackupStatusStore(prefs);
      await status.write(const CloudBackupStatus(revision: 4));
    });

    test(
      'a device with no key can discard a recognised encrypted backup',
      () async {
        // The ordinary discard still refuses without a key.
        expect(
          await serviceWith(noKeys).discardUnreadableCloudBackup(),
          CloudBackupDiscardOutcome.noKeyOnDevice,
        );
        expect(gateway.deleteCalls, 0);

        expect(
          await serviceWith(noKeys).discardCloudBackupForLostKey(),
          CloudBackupDiscardOutcome.discarded,
        );
        expect(gateway.deletedRevisions, <int>[5]);
        expect(gateway.fullBackup, isNull);
        expect(status.read(), isNull);
        // The service never makes a key itself.
        expect(await BackupCipher(noKeys).loadExistingRecoveryKey(), isNull);
      },
    );

    test('a key that opens the backup means it is not lost', () async {
      expect(
        await serviceWith(originalKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.readable,
      );
      expect(gateway.deleteCalls, 0);
    });

    test('refuses anything but a recognised encrypted backup', () async {
      final Map<String, dynamic> encrypted = gateway.fullBackup!;
      final Map<CloudBackupReadResult?, CloudBackupDiscardOutcome> reads = {
        const CloudBackupReadResult.unavailable():
            CloudBackupDiscardOutcome.unavailable,
        const CloudBackupReadResult.malformed():
            CloudBackupDiscardOutcome.cloudBackupUnreadable,
        const CloudBackupReadResult.ownerMismatch():
            CloudBackupDiscardOutcome.ownerMismatch,
        const CloudBackupReadResult.notFound():
            CloudBackupDiscardOutcome.nothingToDiscard,
      };
      for (final MapEntry<CloudBackupReadResult?, CloudBackupDiscardOutcome>
          read
          in reads.entries) {
        gateway.fullReadOverride = read.key;
        expect(
          await serviceWith(noKeys).discardCloudBackupForLostKey(),
          read.value,
        );
      }
      gateway.fullReadOverride = null;

      // A newer app's encryption format.
      gateway.fullBackup = <String, dynamic>{
        'format': 'chronospark_backup_aes256_gcm_v3',
        'iv': 'AAAA',
        'ciphertext': 'AAAA',
      };
      expect(
        await serviceWith(noKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.newerVersion,
      );
      // Content that is not an encrypted backup at all.
      gateway.fullBackup = <String, dynamic>{'unexpected': true};
      expect(
        await serviceWith(noKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.changed,
      );
      // An older plaintext backup needs no key.
      gateway.fullBackup = <String, dynamic>{
        'version': '3.0.0',
        'tasks': <dynamic>[],
      };
      expect(
        await serviceWith(noKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.readable,
      );
      expect(gateway.deleteCalls, 0);

      gateway.fullBackup = encrypted;
      gateway.refuseDelete = true;
      expect(
        await serviceWith(noKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.refused,
      );
      expect(gateway.fullBackup, isNotNull);
      expect(status.read()!.revision, 4);

      gateway.refuseDelete = false;
      gateway.beforeDelete = () async => gateway.revision = 6;
      expect(
        await serviceWith(noKeys).discardCloudBackupForLostKey(),
        CloudBackupDiscardOutcome.changed,
      );
      expect(gateway.fullBackup, isNotNull);
      expect(await BackupCipher(noKeys).loadExistingRecoveryKey(), isNull);
    });
  });
}

Map<String, dynamic> _fullCloudBackup({
  required List<Map<String, dynamic>> tasks,
  Map<String, dynamic>? profile,
  Map<String, dynamic> settings = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'version': '3.0.0',
    'manifest': accountDataBackupManifest(),
    'timestamp': '2026-08-29T12:00:00.000Z',
    'tasks': tasks,
    'profile': profile,
    'settings': settings,
  };
}

class _MemoryCloudBackupGateway
    implements CloudBackupGateway, CloudBackupDiscard {
  bool refuseDelete = false;
  int deleteCalls = 0;
  final List<int> deletedRevisions = <int>[];
  Future<void> Function()? beforeDelete;

  @override
  Future<CloudBackupDeleteStatus> deleteBackup({
    required int expectedRevision,
  }) async {
    await beforeDelete?.call();
    deleteCalls += 1;
    final int current = fullBackup == null ? 0 : (revision == 0 ? 1 : revision);
    if (refuseDelete || fullBackup == null || current != expectedRevision) {
      return CloudBackupDeleteStatus.notDeleted;
    }
    deletedRevisions.add(expectedRevision);
    fullBackup = null;
    revision = 0;
    return CloudBackupDeleteStatus.deleted;
  }

  Map<String, dynamic>? fullBackup;
  Map<String, dynamic>? tasksBackup;
  CloudBackupReadResult? fullReadOverride;
  CloudBackupReadResult? tasksReadOverride;
  bool uploadShouldFail = false;
  int uploadBackupCalls = 0;
  int revision = 0;
  void Function()? onDownloadBackup;
  void Function()? onUploadBackup;
  Future<void> Function()? beforeCompareAndSwap;
  CloudBackupWriteResult? writeOverride;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    onDownloadBackup?.call();
    return fullReadOverride ??
        (fullBackup == null
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
    await beforeCompareAndSwap?.call();
    final CloudBackupWriteResult? forced = writeOverride;
    if (forced != null) return forced;
    final int currentRevision = fullBackup == null
        ? 0
        : (revision == 0 ? 1 : revision);
    if (currentRevision != expectedRevision) {
      return CloudBackupWriteResult.conflict(currentRevision);
    }
    uploadBackupCalls += 1;
    onUploadBackup?.call();
    if (uploadShouldFail) {
      return const CloudBackupWriteResult.unavailable();
    }
    revision = expectedRevision + 1;
    fullBackup = backup;
    return CloudBackupWriteResult.written(revision);
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async {
    return tasksReadOverride ??
        (tasksBackup == null
            ? const CloudBackupReadResult.notFound()
            : CloudBackupReadResult.found(tasksBackup));
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
    uploadBackupCalls += 1;
    onUploadBackup?.call();
    if (uploadShouldFail) {
      return false;
    }
    fullBackup = backup;
    return true;
  }

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async {
    tasksBackup = backup;
    return true;
  }
}

class _DefaultCasGateway extends CloudBackupGateway {
  @override
  Future<CloudBackupReadResult> downloadBackup() async =>
      const CloudBackupReadResult.unavailable();

  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.unavailable();

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
}

class _ConcurrentCasGateway implements CloudBackupGateway {
  _ConcurrentCasGateway(this.fullBackup);

  Map<String, dynamic> fullBackup;
  int revision = 1;
  int successfulWrites = 0;
  int _reads = 0;
  final Completer<void> _bothRead = Completer<void>();

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    _reads += 1;
    if (_reads == 2) _bothRead.complete();
    await _bothRead.future;
    return CloudBackupReadResult.found(
      Map<String, dynamic>.from(fullBackup),
      revision: 1,
    );
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    if (revision != expectedRevision) {
      return CloudBackupWriteResult.conflict(revision);
    }
    revision += 1;
    successfulWrites += 1;
    fullBackup = backup;
    return CloudBackupWriteResult.written(revision);
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.notFound();

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
}

class _LegacyMigrationCleanupGateway
    implements CloudBackupGateway, LegacyFullBackupCleanup {
  _LegacyMigrationCleanupGateway(
    this.legacyPayload, {
    this.cleanupStatus = LegacyFullBackupCleanupStatus.removedOrAbsent,
    this.returnMismatchedReadback = false,
    Map<String, dynamic>? initialCasPayload,
  }) : casPayload = initialCasPayload;

  final Map<String, dynamic> legacyPayload;
  final LegacyFullBackupCleanupStatus cleanupStatus;
  final bool returnMismatchedReadback;
  final List<String> events = <String>[];
  Map<String, dynamic>? casPayload;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    final Map<String, dynamic>? encrypted = casPayload;
    if (encrypted == null) {
      events.add('read-legacy');
      return CloudBackupReadResult.found(legacyPayload, revision: 0);
    }
    events.add('read-cas');
    if (returnMismatchedReadback) {
      return CloudBackupReadResult.found(encrypted, revision: 2);
    }
    return CloudBackupReadResult.found(encrypted, revision: 1);
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    expect(expectedRevision, 0);
    events.add('write-cas');
    casPayload = Map<String, dynamic>.from(backup);
    return const CloudBackupWriteResult.written(1);
  }

  @override
  Future<LegacyFullBackupCleanupStatus> deleteLegacyFullBackup() async {
    events.add('delete-legacy-full-backup');
    return cleanupStatus;
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.notFound();

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};
  void Function(TaskEntity task)? onSave;

  @override
  Future<void> deleteTask(String id) async {
    tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    tasks[task.id] = task;
    onSave?.call(task);
  }
}

class _TestHiveStore implements HiveStore {
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).clear();
      return;
    }
    final Box<String> box = await Hive.openBox<String>(key);
    await box.clear();
    await box.close();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }
}
