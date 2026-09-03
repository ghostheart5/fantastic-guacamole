import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_logs.dart';
import 'package:fantastic_guacamole/domain/usecases/get_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task paging is bounded, ordered, and cursor-safe', () async {
    final DateTime now = DateTime.utc(2026, 9, 3);
    final GetTasks getTasks = GetTasks(
      _TaskRepository(<TaskEntity>[
        for (int index = 1; index <= 4; index += 1)
          TaskEntity(id: 'task-$index', title: 'Task $index', createdAt: now),
      ]),
    );

    expect(await getTasks.call(), hasLength(4));
    final first = await getTasks.page(limit: 2);
    expect(first.items.map((TaskEntity task) => task.id), <String>[
      'task-1',
      'task-2',
    ]);
    expect(first.nextCursor, 'task-2');
    final second = await getTasks.page(cursor: first.nextCursor, limit: 2);
    expect(second.items.map((TaskEntity task) => task.id), <String>[
      'task-3',
      'task-4',
    ]);
    expect(second.nextCursor, isNull);
    expect((await getTasks.page(cursor: 'task-4')).items, isEmpty);
    expect(
      (await getTasks.page(cursor: 'missing', limit: 0)).items.single.id,
      'task-1',
    );
  });

  test('log paging is bounded, ordered, and cursor-safe', () async {
    final DateTime now = DateTime.utc(2026, 9, 3);
    final GetLogs getLogs = GetLogs(
      _LogRepository(<LogEntryEntity>[
        for (int index = 1; index <= 4; index += 1)
          LogEntryEntity(
            id: 'log-$index',
            message: 'Log $index',
            source: 'test',
            timestamp: now,
          ),
      ]),
    );

    expect(await getLogs.call(), hasLength(4));
    final first = await getLogs.page(limit: 2);
    expect(first.items.map((LogEntryEntity log) => log.id), <String>[
      'log-1',
      'log-2',
    ]);
    expect(first.nextCursor, 'log-2');
    final second = await getLogs.page(cursor: first.nextCursor, limit: 2);
    expect(second.items.map((LogEntryEntity log) => log.id), <String>[
      'log-3',
      'log-4',
    ]);
    expect(second.nextCursor, isNull);
    expect((await getLogs.page(cursor: 'log-4')).items, isEmpty);
    expect(
      (await getLogs.page(cursor: 'missing', limit: 0)).items.single.id,
      'log-1',
    );
  });

  test('memory paging is bounded, ordered, and cursor-safe', () {
    final DateTime now = DateTime.utc(2026, 9, 3);
    final GetMemories getMemories = GetMemories(
      _MemoryRepository(<MemoryEntity>[
        for (int index = 1; index <= 4; index += 1)
          MemoryEntity(id: 'memory-$index', text: 'Memory $index', date: now),
      ]),
    );

    expect(getMemories.call(), hasLength(4));
    final first = getMemories.page(limit: 2);
    expect(first.items.map((MemoryEntity memory) => memory.id), <String>[
      'memory-1',
      'memory-2',
    ]);
    expect(first.nextCursor, 'memory-2');
    final second = getMemories.page(cursor: first.nextCursor, limit: 2);
    expect(second.items.map((MemoryEntity memory) => memory.id), <String>[
      'memory-3',
      'memory-4',
    ]);
    expect(second.nextCursor, isNull);
    expect(getMemories.page(cursor: 'memory-4').items, isEmpty);
    expect(
      getMemories.page(cursor: 'missing', limit: 0).items.single.id,
      'memory-1',
    );
  });
}

final class _TaskRepository implements ITaskRepository {
  _TaskRepository(this.tasks);

  final List<TaskEntity> tasks;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

final class _LogRepository implements ILogRepository {
  _LogRepository(this.logs);

  final List<LogEntryEntity> logs;

  @override
  Future<void> addLog(LogEntryEntity entry) async {}

  @override
  Future<List<LogEntryEntity>> getLogs() async => logs;
}

final class _MemoryRepository implements IMemoryRepository {
  _MemoryRepository(this.memories);

  final List<MemoryEntity> memories;

  @override
  Future<void> deleteAllMemories() async => memories.clear();

  @override
  Future<void> deleteMemory(String id) async {}

  @override
  List<MemoryEntity> getMemories() => memories;

  @override
  List<MemoryEntity> getMemoriesForSurface(MemorySurface surface) => memories;

  @override
  Future<void> saveMemories(List<MemoryEntity> memories) async {}

  @override
  Future<void> saveMemory(MemoryEntity memory) async {}
}
