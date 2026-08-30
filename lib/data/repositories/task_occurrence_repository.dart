import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';

class TaskOccurrenceRepository {
  TaskOccurrenceRepository(HiveStorage<String> storage) : _storage = storage;
  TaskOccurrenceRepository.unavailable() : _storage = null;

  static const String persistenceKey = 'task_occurrences_v2';
  static const String quarantineKey = 'task_occurrences_v2_quarantine';
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

  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      (await _read())
          .where((TaskOccurrence item) => item.taskId == taskId)
          .toList(growable: false);

  Future<List<TaskOccurrence>> listOccurrences() async =>
      List<TaskOccurrence>.unmodifiable(await _read());

  Future<List<dynamic>> listQuarantinedRecords() async {
    final HiveStorage<String> storage = _requireStorage();
    await storage.open();
    final String? raw = storage.get(quarantineKey);
    if (raw == null || raw.trim().isEmpty) return const <dynamic>[];
    final Object? decoded = jsonDecode(raw);
    return decoded is List<dynamic>
        ? List<dynamic>.unmodifiable(decoded)
        : <dynamic>[decoded];
  }

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

  Future<void> replaceSnapshot(List<TaskOccurrence> occurrences) {
    final List<TaskOccurrence> snapshot = List<TaskOccurrence>.unmodifiable(
      occurrences,
    );
    return _serializeWrite(() => _write(snapshot));
  }

  Future<List<TaskOccurrence>> _read() async {
    final HiveStorage<String> storage = _requireStorage();
    await storage.open();
    final String? raw = storage.get(persistenceKey);
    if (raw == null || raw.trim().isEmpty) return <TaskOccurrence>[];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await _quarantine(<dynamic>[raw]);
      return <TaskOccurrence>[];
    }
    if (decoded is! List<dynamic>) {
      await _quarantine(<dynamic>[decoded]);
      return <TaskOccurrence>[];
    }
    final List<TaskOccurrence> valid = <TaskOccurrence>[];
    final List<dynamic> malformed = <dynamic>[];
    for (final dynamic value in decoded) {
      if (value is! Map<dynamic, dynamic>) {
        malformed.add(value);
        continue;
      }
      try {
        valid.add(
          TaskOccurrence.fromJson(
            value.map<String, dynamic>(
              (dynamic key, dynamic item) => MapEntry(key.toString(), item),
            ),
          ),
        );
      } on FormatException {
        malformed.add(value);
      }
    }
    if (malformed.isNotEmpty) await _quarantine(malformed);
    return valid;
  }

  Future<void> _quarantine(List<dynamic> malformed) async {
    const int maxQuarantinedRecords = 100;
    final HiveStorage<String> storage = _requireStorage();
    final String? existingRaw = storage.get(quarantineKey);
    final List<dynamic> records = <dynamic>[];
    if (existingRaw != null && existingRaw.trim().isNotEmpty) {
      try {
        final Object? existing = jsonDecode(existingRaw);
        if (existing is List<dynamic>) records.addAll(existing);
      } on FormatException {
        records.add(existingRaw);
      }
    }
    records.addAll(malformed);
    final int overflow = records.length - maxQuarantinedRecords;
    if (overflow > 0) records.removeRange(0, overflow);
    await storage.put(quarantineKey, jsonEncode(records));
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
        'Task occurrence storage is unavailable during account transition.',
      ));
}
