import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _MemoryTaskRepository repository;
  late BackupService service;
  late Directory hiveDirectory;
  late HiveStorage<String> profileStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_backup_test_',
    );
    Hive.init(hiveDirectory.path);
    repository = _MemoryTaskRepository();
    profileStorage = HiveStorage<String>('profile_box', hive: _TestHiveStore());
    service = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: SharedPrefsStorage(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() async {
    await profileStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('backs up canonical task fields', () async {
    final DateTime createdAt = DateTime.utc(2026, 7, 4, 12);
    final DateTime dueDate = DateTime.utc(2026, 7, 8);
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Canonical task',
        description: 'Full domain record',
        createdAt: createdAt,
        priority: 5,
        difficulty: 4,
        energyRequired: 2,
        estimatedDuration: const Duration(minutes: 45),
        dueDate: dueDate,
        goalId: 'goal-1',
        subtasks: const <String>['Draft', 'Review'],
        recurrenceRule: RecurrenceRule.weekly,
      ),
    );

    final Map<String, dynamic> backup = await service.backupTasks();
    final Map<String, dynamic> task =
        (backup['tasks'] as List<dynamic>).single as Map<String, dynamic>;

    expect(task['id'], 'task-1');
    expect(task['priority'], 5);
    expect(task['estimatedDurationMs'], 2700000);
    expect(task['dueDate'], dueDate.toIso8601String());
    expect(task['goalId'], 'goal-1');
    expect(task['recurrenceRule'], 'weekly');
  });

  test('restore replaces repository records with canonical entities', () async {
    await repository.saveTask(
      TaskEntity(id: 'old', title: 'Remove me', createdAt: DateTime.utc(2025)),
    );

    await service.restoreTasks(<String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'restored',
          'title': 'Restored task',
          'createdAt': '2026-07-04T12:00:00.000Z',
          'isCompleted': true,
          'priority': 4,
          'difficulty': 2,
          'energyRequired': 3,
          'completedAt': '2026-07-04T13:00:00.000Z',
          'subtasks': <String>['One'],
          'recurrenceRule': 'daily',
        },
      ],
    });

    expect(await repository.getTaskById('old'), isNull);
    final TaskEntity? restored = await repository.getTaskById('restored');
    expect(restored, isNotNull);
    expect(restored!.isCompleted, isTrue);
    expect(restored.priority, 4);
    expect(restored.recurrenceRule, RecurrenceRule.daily);
  });

  test('an empty task backup clears canonical tasks', () async {
    await repository.saveTask(
      TaskEntity(id: 'old', title: 'Remove me', createdAt: DateTime.utc(2025)),
    );

    await service.restoreTasks(<String, dynamic>{'tasks': <dynamic>[]});

    expect(await repository.getAllTasks(), isEmpty);
  });

  test('createFullBackup includes tasks profile and settings', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Ship audit',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Keegan', 'xp': 42}),
    );
    await service.prefs.setJson('settings', <String, dynamic>{
      'soundEnabled': false,
    });

    final Map<String, dynamic> backup = await service.createFullBackup();
    final Map<String, dynamic> task =
        ((backup['tasks'] as List<dynamic>).single as Map<dynamic, dynamic>)
            .map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            );

    expect(backup['version'], '3.0.0');
    expect(backup['manifest'], isA<Map<String, dynamic>>());
    expect(
      ((backup['manifest'] as Map<String, dynamic>)['includedDomains']
              as List<dynamic>)
          .cast<String>(),
      containsAll(<String>['tasks', 'profile', 'settings']),
    );
    expect(
      ((backup['manifest'] as Map<String, dynamic>)['excludedDomains']
              as List<dynamic>)
          .cast<String>(),
      contains('timeline'),
    );
    expect(task['id'], 'task-1');
    expect(backup['profile'], <String, dynamic>{'name': 'Keegan', 'xp': 42});
    expect(backup['settings'], <String, dynamic>{'soundEnabled': false});
  });

  test('backupProfile and backupSettings expose stored state', () async {
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Nova', 'xp': 7}),
    );
    await service.prefs.setJson('settings', <String, dynamic>{
      'soundEnabled': true,
    });

    final Map<String, dynamic> profileBackup = await service.backupProfile();
    final Map<String, dynamic> settingsBackup = await service.backupSettings();

    expect(profileBackup['profile'], <String, dynamic>{
      'name': 'Nova',
      'xp': 7,
    });
    expect(settingsBackup['settings'], <String, dynamic>{'soundEnabled': true});
    expect(profileBackup['timestamp'], isA<String>());
    expect(settingsBackup['timestamp'], isA<String>());
  });

  test(
    'backupProfile returns null when profile state is missing or malformed',
    () async {
      expect((await service.backupProfile())['profile'], isNull);

      await profileStorage.put('profile_state', '{not valid json');

      expect((await service.backupProfile())['profile'], isNull);
    },
  );

  test('export helpers serialize canonical backup payloads', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Export me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Exporter'}),
    );

    final Map<String, dynamic> fullBackup =
        jsonDecode(await service.exportFullBackupString())
            as Map<String, dynamic>;
    final Map<String, dynamic> tasksBackup =
        jsonDecode(await service.exportTasksString()) as Map<String, dynamic>;

    expect(fullBackup['version'], '3.0.0');
    expect(
      (fullBackup['tasks'] as List<dynamic>).single,
      isA<Map<String, dynamic>>(),
    );
    expect(
      (tasksBackup['tasks'] as List<dynamic>).single,
      isA<Map<String, dynamic>>(),
    );
  });

  test(
    'restoreFullBackup restores profile and settings alongside tasks',
    () async {
      await service.restoreFullBackup(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'restored',
            'title': 'Restored task',
            'createdAt': '2026-07-05T08:00:00.000Z',
          },
        ],
        'profile': <String, dynamic>{'name': 'Recovered', 'xp': 12},
        'settings': <String, dynamic>{'soundEnabled': true, 'theme': 'neon'},
      });

      expect((await repository.getAllTasks()).single.id, 'restored');
      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Recovered', 'xp': 12}),
      );
      expect(service.prefs.getJson('settings'), <String, dynamic>{
        'soundEnabled': true,
        'theme': 'neon',
      });
    },
  );

  test(
    'restoreFullBackup accepts legacy user fallback and skips invalid settings',
    () async {
      await service.prefs.setJson('settings', <String, dynamic>{
        'theme': 'existing',
      });

      await service.restoreFullBackup(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[],
        'user': <String, dynamic>{'name': 'Legacy Restore'},
        'settings': 'not a map',
      });

      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{
          'xp': 0,
          'level': 1,
          'streak': 0,
          'longestStreak': 0,
          'name': 'Legacy Restore',
          'soundEnabled': true,
          'lastActiveDate': null,
        }),
      );
      expect(service.prefs.getJson('settings'), <String, dynamic>{
        'theme': 'existing',
      });
    },
  );

  test('restoreProfile supports legacy user payload fallback', () async {
    await service.restoreProfile(<String, dynamic>{
      'user': <String, dynamic>{'name': 'Legacy Pilot'},
    });

    expect(
      profileStorage.get('profile_state'),
      jsonEncode(<String, dynamic>{
        'xp': 0,
        'level': 1,
        'streak': 0,
        'longestStreak': 0,
        'name': 'Legacy Pilot',
        'soundEnabled': true,
        'lastActiveDate': null,
      }),
    );
  });

  test(
    'restoreProfile ignores blank legacy users and restoreSettings ignores non-map payloads',
    () async {
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Keep Me'}),
      );
      await service.prefs.setJson('settings', <String, dynamic>{
        'theme': 'existing',
      });

      await service.restoreProfile(<String, dynamic>{
        'user': <String, dynamic>{'name': '   '},
      });
      await service.restoreSettings(<String, dynamic>{'settings': 'invalid'});

      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Keep Me'}),
      );
      expect(service.prefs.getJson('settings'), <String, dynamic>{
        'theme': 'existing',
      });
    },
  );

  test('restoreTasks ignores missing tasks payload', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'keep',
        title: 'Keep me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );

    await service.restoreTasks(<String, dynamic>{'tasks': 'invalid'});

    expect((await repository.getAllTasks()).single.id, 'keep');
  });

  test('restoreTasks throws when backup has no valid task records', () async {
    await expectLater(
      () => service.restoreTasks(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Missing required id and createdAt'},
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'failed task replacement rolls back the complete prior task set',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Preserve this task',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      repository.failFirstSaveForId = 'restore-fails';

      await expectLater(
        () => service.restoreTasks(<String, dynamic>{
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'restore-starts',
              'title': 'Partially restored task',
              'createdAt': '2026-08-02T00:00:00.000Z',
            },
            <String, dynamic>{
              'id': 'restore-fails',
              'title': 'Triggers rollback',
              'createdAt': '2026-08-03T00:00:00.000Z',
            },
          ],
        }),
        throwsStateError,
      );

      final List<TaskEntity> tasks = await repository.getAllTasks();
      expect(tasks.map((TaskEntity task) => task.id), <String>['existing']);
    },
  );

  test(
    'migrates legacy profile data to secure storage before writes',
    () async {
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final BackupService secureService = BackupService(
        taskRepository: repository,
        profileStorage: profileStorage,
        prefs: service.prefs,
        secureProfileStore: secureStore,
      );
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Legacy Secure User'}),
      );

      expect(
        (await secureService.backupProfile())['profile'],
        <String, dynamic>{'name': 'Legacy Secure User'},
      );
      expect(profileStorage.get('profile_state'), isNull);
      expect(
        await secureStore.readString('profile_state_v2'),
        jsonEncode(<String, dynamic>{'name': 'Legacy Secure User'}),
      );

      await secureService.restoreProfile(<String, dynamic>{
        'profile': <String, dynamic>{'name': 'Secure Restore'},
      });
      await secureService.restoreSettings(<String, dynamic>{
        'settings': <String, dynamic>{'soundEnabled': false},
      });

      expect(
        await secureStore.readString('profile_state_v2'),
        jsonEncode(<String, dynamic>{'name': 'Secure Restore'}),
      );
      expect(secureService.prefs.getJson('settings'), <String, dynamic>{
        'soundEnabled': false,
      });
    },
  );
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  String? failFirstSaveForId;
  bool _didFailConfiguredSave = false;

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
    if (!_didFailConfiguredSave && task.id == failFirstSaveForId) {
      _didFailConfiguredSave = true;
      throw StateError('Simulated restore write failure for ${task.id}.');
    }
    _tasks[task.id] = task;
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
