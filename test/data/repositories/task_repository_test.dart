import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
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
    final task = TaskEntity(id: 'task-1', title: 'Persist me', createdAt: DateTime.utc(2026, 7, 5));

    await repository.saveTask(task);

    final loaded = await repository.getTaskById('task-1');
    expect(loaded, isNotNull);
    expect(loaded?.id, 'task-1');
    expect(loaded?.title, 'Persist me');
  });

  test('deletes task by id', () async {
    final repository = TaskRepository(storage: storage);
    final task = TaskEntity(
      id: 'task-delete',
      title: 'Delete me',
      createdAt: DateTime.utc(2026, 7, 5),
    );

    await repository.saveTask(task);
    await repository.deleteTask('task-delete');

    expect(await repository.getTaskById('task-delete'), isNull);
  });

  test('returns paged tasks newest first with cursor continuation', () async {
    final repository = TaskRepository(storage: storage);
    await repository.saveTask(
      TaskEntity(id: 'task-1', title: 'One', createdAt: DateTime.utc(2026, 7, 5, 8)),
    );
    await repository.saveTask(
      TaskEntity(id: 'task-2', title: 'Two', createdAt: DateTime.utc(2026, 7, 5, 9)),
    );
    await repository.saveTask(
      TaskEntity(id: 'task-3', title: 'Three', createdAt: DateTime.utc(2026, 7, 5, 10)),
    );

    final firstPage = await repository.getTasksPage(limit: 2);
    final secondPage = await repository.getTasksPage(cursor: firstPage.nextCursor, limit: 2);

    expect(firstPage.items.map((TaskEntity task) => task.id), <String>['task-3', 'task-2']);
    expect(firstPage.nextCursor, 'task-2');
    expect(secondPage.items.map((TaskEntity task) => task.id), <String>['task-1']);
    expect(secondPage.nextCursor, isNull);
  });

  test('secure mode migrates legacy hive entries and clears legacy box', () async {
    final legacy = HiveStorage<String>('legacy_tasks_box', hive: _DirectHiveStore());
    await legacy.open();
    final legacyTask = TaskEntity(
      id: 'legacy-1',
      title: 'Legacy task',
      createdAt: DateTime.utc(2026, 7, 5),
    );
    await legacy.put(
      legacyTask.id,
      jsonEncode(<String, dynamic>{
        'id': legacyTask.id,
        'title': legacyTask.title,
        'createdAt': legacyTask.createdAt.toIso8601String(),
      }),
    );

    final backend = InMemorySecureStoreBackend();
    final repository = TaskRepository.secure(SecureStore(backend: backend), legacyStorage: legacy);

    final tasks = await repository.getAllTasks();

    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'legacy-1');
    expect(legacy.getAll(), isEmpty);
  });

  test('returns storage failure when secure snapshot is malformed', () async {
    final backend = InMemorySecureStoreBackend();
    final secureStore = SecureStore(backend: backend);
    await secureStore.writeString('task_entries_v2', '{"bad":"{not-json"}');
    final repository = TaskRepository.secure(secureStore);

    await expectLater(() => repository.getAllTasks(), throwsA(isA<StorageException>()));
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
    final box = Hive.isBoxOpen(key) ? Hive.box<String>(key) : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }
}
