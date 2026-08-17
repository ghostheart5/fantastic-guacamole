import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_sync_test_',
    );
    Hive.init(hiveDirectory.path);
    repository = _MemoryTaskRepository();
    profileStorage = HiveStorage<String>('profile_box', hive: _TestHiveStore());
    prefs = SharedPrefsStorage(await SharedPreferences.getInstance());
    backupService = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: prefs,
    );
    gateway = _MemoryCloudBackupGateway();
    syncService = SyncService(backup: backupService, gateway: gateway);
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

  test('restoreFromCloud returns false when cloud backup is empty', () async {
    final bool restored = await syncService.restoreFromCloud();

    expect(restored, isFalse);
  });

  test('restoreFromCloud restores tasks profile and settings', () async {
    gateway.fullBackup = <String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cloud-1',
          'title': 'From cloud',
          'createdAt': '2026-07-05T08:00:00.000Z',
        },
      ],
      'profile': <String, dynamic>{'name': 'Cloud User'},
      'settings': <String, dynamic>{'soundEnabled': false},
    };

    final bool restored = await syncService.restoreFromCloud();

    expect(restored, isTrue);
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
    'syncDelta merges newer local task over older cloud task and restores merged data',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'shared',
          title: 'Local newer',
          createdAt: DateTime.utc(2026, 7, 5, 12),
        ),
      );
      gateway.fullBackup = <String, dynamic>{
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[
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
        'settings': <String, dynamic>{'theme': 'cloud'},
      };

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
    gateway.fullBackup = <String, dynamic>{
      'version': '3.0.0',
      'tasks': <Map<String, dynamic>>[],
    };
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
    gateway.fullBackup = <String, dynamic>{
      'version': '3.0.0',
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Cloud newer',
          'updatedAt': '2026-07-05T12:00:00.000Z',
          'createdAt': '2026-07-05T07:00:00.000Z',
        },
      ],
    };

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
    gateway.fullBackup = <String, dynamic>{
      'version': '3.0.0',
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Cloud edit',
          'createdAt': '2026-07-05T10:00:00.000Z',
        },
      ],
    };

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
    gateway.fullBackup = <String, dynamic>{
      'version': '3.0.0',
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'cloud-only',
          'title': 'From another device',
          'createdAt': '2026-07-05T09:00:00.000Z',
        },
      ],
    };

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
      gateway.fullBackup = <String, dynamic>{
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'shared',
            'title': 'Cloud created later, never completed',
            'createdAt': '2026-07-05T00:00:00.000Z',
          },
        ],
      };

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
    gateway.fullBackup = <String, dynamic>{
      'version': '3.0.0',
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shared',
          'title': 'Stale cloud title',
          'createdAt': '2026-07-05T00:00:00.000Z',
          'updatedAt': '2026-07-05T12:00:00.000Z',
        },
      ],
    };

    expect(await syncService.syncDelta(), isTrue);
    expect(mergedTasks().single['title'], 'Locally renamed, never synced');
    expect(mergedTasks().single['updatedAt'], '2026-07-06T00:00:00.000Z');
  });

  test(
    'syncDelta resurrects a locally deleted task that is still in the cloud',
    () async {
      // Documents a real gap rather than endorsing it: there are no tombstones,
      // so deleting on one device and syncing brings the task back. Asserting
      // it here means adding deletion tracking will fail this test loudly
      // instead of changing behaviour unnoticed.
      gateway.fullBackup = <String, dynamic>{
        'version': '3.0.0',
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'deleted-here',
            'title': 'Deleted on this device',
            'createdAt': '2026-07-05T09:00:00.000Z',
          },
        ],
      };

      expect(await syncService.syncDelta(), isTrue);
      expect(
        mergedTasks().single['id'],
        'deleted-here',
        reason: 'No tombstone support: cloud copy wins over a local deletion.',
      );
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
      expect(await localGateway.downloadBackup(), backup);
      expect(await localGateway.downloadTasks(), tasks);
    },
  );

  test(
    'unavailable cloud backup gateway always returns empty or false',
    () async {
      const UnavailableCloudBackupGateway gateway =
          UnavailableCloudBackupGateway();

      expect(await gateway.uploadBackup(<String, dynamic>{}), isFalse);
      expect(await gateway.uploadTasks(<String, dynamic>{}), isFalse);
      expect(await gateway.downloadBackup(), isEmpty);
      expect(await gateway.downloadTasks(), isEmpty);
    },
  );
}

class _MemoryCloudBackupGateway implements CloudBackupGateway {
  Map<String, dynamic>? fullBackup;
  Map<String, dynamic>? tasksBackup;
  bool uploadShouldFail = false;

  @override
  Future<Map<String, dynamic>> downloadBackup() async {
    return fullBackup ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> downloadTasks() async {
    return tasksBackup ?? <String, dynamic>{};
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
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

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};

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
