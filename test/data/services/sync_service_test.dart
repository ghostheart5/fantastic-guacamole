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
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      settings: <String, dynamic>{'soundEnabled': false},
    );

    final CloudRestoreOutcome restored = await syncService.restoreFromCloud();

    expect(restored, CloudRestoreOutcome.restored);
    expect((await repository.getAllTasks()).single.id, 'cloud-1');
    expect(
      profileStorage.get('profile_state'),
      jsonEncode(<String, dynamic>{'name': 'Cloud User'}),
    );
    expect(prefs.getJson('settings'), <String, dynamic>{'soundEnabled': false});
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
        settings: <String, dynamic>{'theme': 'cloud'},
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
    },
  );
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

class _MemoryCloudBackupGateway implements CloudBackupGateway {
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
