import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorage<String> storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('task_repository_test_');
    await Hive.close();
    Hive.init(tempDir.path);
    storage = HiveStorage<String>(HiveBoxes.tasks, hive: _DirectHiveStore());
    await storage.open();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reads empty storage safely', () async {
    final repository = TaskRepository(storage: storage);

    final tasks = await repository.getAllTasks();

    expect(tasks, isEmpty);
  });

  test('writes task and reads it back', () async {
    final repository = TaskRepository(storage: storage);
    final task = TaskEntity(
      id: 'task-1',
      title: 'Persist me',
      createdAt: DateTime.utc(2026, 7, 5),
      updatedAt: DateTime.utc(2026, 7, 6, 9, 30),
    );

    await repository.saveTask(task);

    final loaded = await repository.getTaskById('task-1');
    expect(loaded, isNotNull);
    expect(loaded?.id, 'task-1');
    expect(loaded?.title, 'Persist me');
    expect(loaded?.updatedAt, DateTime.utc(2026, 7, 6, 9, 30));
  });

  test('hides a deleted task while retaining a sync tombstone', () async {
    final repository = TaskRepository(storage: storage);
    final task = TaskEntity(
      id: 'task-delete',
      title: 'Delete me',
      createdAt: DateTime.utc(2026, 7, 5),
    );

    await repository.saveTask(task);
    await repository.deleteTask('task-delete');

    expect(await repository.getTaskById('task-delete'), isNull);
    final TaskEntity tombstone = (await repository.getAllTasks()).single;
    expect(tombstone.id, 'task-delete');
    expect(tombstone.isCanceled, isTrue);
    expect(tombstone.updatedAt, isNotNull);
  });

  test('exact snapshot replacement removes obsolete tombstones', () async {
    final repository = TaskRepository(storage: storage);
    final TaskEntity keep = TaskEntity(
      id: 'task-keep',
      title: 'Keep me',
      createdAt: DateTime.utc(2026, 7, 5),
    );
    await repository.saveTask(keep);
    await repository.saveTask(
      TaskEntity(
        id: 'task-remove',
        title: 'Remove me',
        createdAt: DateTime.utc(2026, 7, 6),
      ),
    );
    await repository.deleteTask('task-remove');

    await repository.replaceTaskSnapshot(<TaskEntity>[keep]);

    final List<TaskEntity> tasks = await repository.getAllTasks();
    expect(tasks.map((TaskEntity task) => task.id), <String>['task-keep']);
    expect(storage.get('task-remove'), isNull);
  });

  test(
    'recovers an interrupted exact snapshot before returning tasks',
    () async {
      final repository = TaskRepository(storage: storage);
      final TaskEntity original = TaskEntity(
        id: 'original-task',
        title: 'Original',
        createdAt: DateTime.utc(2026, 7, 5),
      );
      await repository.saveTask(original);
      final String originalRaw = storage.get(original.id)!;
      await storage.put(
        TaskRepository.snapshotRecoveryKey,
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'original': <String, String>{original.id: originalRaw},
        }),
      );
      await storage.put(
        'partial-task',
        jsonEncode(
          TaskEntityMapper.toJson(
            TaskEntity(
              id: 'partial-task',
              title: 'Partial',
              createdAt: DateTime.utc(2026, 7, 6),
            ),
          ),
        ),
      );

      final List<TaskEntity> recovered = await repository.getAllTasks();

      expect(recovered.map((TaskEntity task) => task.id), <String>[
        original.id,
      ]);
      expect(storage.get('partial-task'), isNull);
      expect(storage.get(TaskRepository.snapshotRecoveryKey), isNull);
    },
  );

  test('task writes wait for an account cleanup mutation', () async {
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final repository = TaskRepository(
      storage: storage,
      mutationCoordinator: coordinator,
    );
    final Completer<void> cleanupStarted = Completer<void>();
    final Completer<void> releaseCleanup = Completer<void>();
    final Future<void> cleanup = runAccountStorageMutation(() async {
      cleanupStarted.complete();
      await releaseCleanup.future;
    }, coordinator: coordinator);
    await cleanupStarted.future;

    final Future<void> save = repository.saveTask(
      TaskEntity(
        id: 'task-after-cleanup',
        title: 'Serialized',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(storage.get('task-after-cleanup'), isNull);

    releaseCleanup.complete();
    await Future.wait(<Future<void>>[cleanup, save]);
    expect(storage.get('task-after-cleanup'), isNotNull);
  });

  test('nested account mutation can save without deadlocking', () async {
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final repository = TaskRepository(
      storage: storage,
      mutationCoordinator: coordinator,
    );

    await runAccountStorageMutation(
      () => repository.saveTask(
        TaskEntity(
          id: 'nested-task',
          title: 'Nested',
          createdAt: DateTime.utc(2026, 7, 5),
        ),
      ),
      coordinator: coordinator,
    ).timeout(const Duration(seconds: 1));

    expect(await repository.getTaskById('nested-task'), isNotNull);
  });

  test('returns paged tasks newest first with cursor continuation', () async {
    final repository = TaskRepository(storage: storage);
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'One',
        createdAt: DateTime.utc(2026, 7, 5, 8),
      ),
    );
    await repository.saveTask(
      TaskEntity(
        id: 'task-2',
        title: 'Two',
        createdAt: DateTime.utc(2026, 7, 5, 9),
      ),
    );
    await repository.saveTask(
      TaskEntity(
        id: 'task-3',
        title: 'Three',
        createdAt: DateTime.utc(2026, 7, 5, 10),
      ),
    );

    final firstPage = await repository.getTasksPage(limit: 2);
    final secondPage = await repository.getTasksPage(
      cursor: firstPage.nextCursor,
      limit: 2,
    );

    expect(firstPage.items.map((TaskEntity task) => task.id), <String>[
      'task-3',
      'task-2',
    ]);
    expect(firstPage.nextCursor, 'task-2');
    expect(secondPage.items.map((TaskEntity task) => task.id), <String>[
      'task-1',
    ]);
    expect(secondPage.nextCursor, isNull);
  });

  test('quarantines malformed records without hiding valid tasks', () async {
    final repository = TaskRepository(storage: storage);
    await repository.saveTask(
      TaskEntity(
        id: 'valid-task',
        title: 'Keep this task',
        createdAt: DateTime.utc(2026, 8, 19),
      ),
    );
    await storage.put('malformed-task', '{ malformed-json');

    final List<TaskEntity> tasks = await repository.getAllTasks();

    expect(tasks.map((TaskEntity task) => task.id), contains('valid-task'));
    expect(
      tasks.map((TaskEntity task) => task.id),
      isNot(contains('malformed-task')),
    );
    final String? quarantine = storage.get(TaskRepository.quarantineKey);
    expect(quarantine, isNotNull);
    expect(quarantine, contains('malformed-task'));
    expect(quarantine, contains('{ malformed-json'));

    await repository.getAllTasks();
    final List<dynamic> records =
        jsonDecode(storage.get(TaskRepository.quarantineKey)!) as List<dynamic>;
    expect(records, hasLength(1));
  });
}

class _DirectHiveStore implements HiveStore {
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

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final box = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }
}
