import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';

/// Account-scoped durable work list for occurrence read-model reconciliation.
class TaskOccurrenceProjectionWorkRepository {
  TaskOccurrenceProjectionWorkRepository(HiveStorage<String> storage)
    : _storage = storage;
  TaskOccurrenceProjectionWorkRepository.unavailable() : _storage = null;

  static const String persistenceKey = 'task_occurrence_projection_work_v2';
  final HiveStorage<String>? _storage;
  Future<void> _tail = Future<void>.value();
  bool _cancelled = false;

  Future<List<TaskOccurrenceProjectionWork>> listPending() async {
    return (await _read())
        .where(
          (TaskOccurrenceProjectionWork work) => work.stages.values.any(
            (TaskOccurrenceProjectionStageState state) =>
                state == TaskOccurrenceProjectionStageState.pending,
          ),
        )
        .toList(growable: false);
  }

  Future<TaskOccurrenceProjectionWork?> getById(String id) async {
    for (final TaskOccurrenceProjectionWork work in await _read()) {
      if (work.id == id) return work;
    }
    return null;
  }

  Future<void> save(TaskOccurrenceProjectionWork work) => _serialize(() async {
    final List<TaskOccurrenceProjectionWork> all = await _read();
    final int index = all.indexWhere(
      (TaskOccurrenceProjectionWork value) => value.id == work.id,
    );
    if (index < 0) {
      all.add(work);
    } else {
      all[index] = work;
    }
    await _storageOrThrow().put(
      persistenceKey,
      jsonEncode(
        all
            .map((TaskOccurrenceProjectionWork value) => value.toJson())
            .toList(),
      ),
    );
  });

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _tail.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;

  Future<List<TaskOccurrenceProjectionWork>> _read() async {
    final HiveStorage<String> storage = _storageOrThrow();
    await storage.open();
    final String? raw = storage.get(persistenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return <TaskOccurrenceProjectionWork>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'Task occurrence projection work is not a list.',
      );
    }
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> value) =>
              TaskOccurrenceProjectionWork.fromJson(
                value.map<String, dynamic>(
                  (dynamic key, dynamic item) => MapEntry(key.toString(), item),
                ),
              ),
        )
        .toList(growable: true);
  }

  Future<void> _serialize(Future<void> Function() operation) {
    if (_cancelled) {
      return Future<void>.error(
        StateError(
          'Task occurrence projection work is unavailable during transition.',
        ),
      );
    }
    final Future<void> next = _tail
        .catchError((Object _) {})
        .then((_) => operation());
    _tail = next.catchError((Object _) {});
    return next;
  }

  HiveStorage<String> _storageOrThrow() =>
      _storage ??
      (throw StateError(
        'Task occurrence projection work is unavailable outside an authenticated scope.',
      ));
}
