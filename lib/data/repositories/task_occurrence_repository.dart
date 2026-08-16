import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';

/// Account-local durable authority for task occurrence outcomes.
class TaskOccurrenceRepository {
  TaskOccurrenceRepository(HiveStorage<String> storage) : _storage = storage;
  TaskOccurrenceRepository.unavailable() : _storage = null;

  static const String persistenceKey = 'task_occurrences_v2';
  final HiveStorage<String>? _storage;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;

  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async => (await _read()).cast<TaskOccurrence?>().firstWhere(
    (TaskOccurrence? item) =>
        item?.taskId == taskId && item?.occurrenceKey == occurrenceKey,
    orElse: () => null,
  );

  Future<TaskOccurrence?> getByOccurrenceId(String occurrenceId) async =>
      (await _read()).cast<TaskOccurrence?>().firstWhere(
        (TaskOccurrence? item) => item?.id == occurrenceId,
        orElse: () => null,
      );

  Future<TaskOccurrence?> getByOperationId(String operationId) async =>
      (await _read()).cast<TaskOccurrence?>().firstWhere(
        (TaskOccurrence? item) =>
            item?.hasCommittedOperation(operationId) ?? false,
        orElse: () => null,
      );

  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      (await _read())
          .where((TaskOccurrence item) => item.taskId == taskId)
          .toList(growable: false);

  Future<void> save(TaskOccurrence occurrence) => _serializeWrite(() async {
    final List<TaskOccurrence> all = await _read();
    final int index = all.indexWhere(
      (TaskOccurrence item) => item.id == occurrence.id,
    );
    if (index < 0) {
      all.add(occurrence);
    } else {
      all[index] = occurrence;
    }
    await _write(all);
  });

  Future<List<TaskOccurrence>> _read() async {
    final HiveStorage<String> storage = _requireStorage();
    await storage.open();
    final String? raw = storage.get(persistenceKey);
    if (raw == null || raw.trim().isEmpty) return <TaskOccurrence>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Task occurrence storage is not a list.');
    }
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> value) => TaskOccurrence.fromJson(
            value.map<String, dynamic>(
              (dynamic key, dynamic item) => MapEntry(key.toString(), item),
            ),
          ),
        )
        .toList(growable: true);
  }

  Future<void> _write(List<TaskOccurrence> occurrences) =>
      _requireStorage().put(
        persistenceKey,
        jsonEncode(
          occurrences
              .map((TaskOccurrence occurrence) => occurrence.toJson())
              .toList(growable: false),
        ),
      );

  Future<void> _serializeWrite(Future<void> Function() action) {
    if (_cancelled) {
      return Future<void>.error(
        StateError(
          'Task occurrence mutation canceled during account transition.',
        ),
      );
    }
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  HiveStorage<String> _requireStorage() =>
      _storage ??
      (throw StateError(
        'Task occurrence storage is unavailable while the account transition is unsafe.',
      ));
}
