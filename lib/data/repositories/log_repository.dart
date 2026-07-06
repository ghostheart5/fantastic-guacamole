import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/log_entry_record.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';

class LogRepository implements ILogRepository {
  LogRepository(this._store);

  static const String _entriesKey = 'chrono_log_entries_v2';
  final SecureStore _store;

  @override
  Future<List<LogEntryEntity>> getLogs() async {
    final String? raw = await _store.readString(_entriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <LogEntryEntity>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Log storage is not a list.');
      }
      final List<LogEntryEntity> entries = <LogEntryEntity>[];
      for (final Object? value in decoded) {
        if (value is! Map) {
          continue;
        }
        try {
          final Map<String, dynamic> json = value.map(
            (dynamic key, dynamic item) => MapEntry(key.toString(), item),
          );
          entries.add(LogEntryRecord.fromJson(json).toEntity());
        } on FormatException catch (error) {
          Logger.warn('Skipping malformed log entry: $error');
        }
      }
      entries.sort(
        (LogEntryEntity a, LogEntryEntity b) =>
            b.timestamp.compareTo(a.timestamp),
      );
      return entries;
    } on FormatException catch (error) {
      Logger.error('Stored logs are corrupt.', error);
      return const <LogEntryEntity>[];
    }
  }

  @override
  Future<void> addLog(LogEntryEntity entry) async {
    final List<LogEntryEntity> entries = await getLogs();
    final List<LogEntryEntity> updated = <LogEntryEntity>[
      entry,
      ...entries.where((LogEntryEntity item) => item.id != entry.id),
    ];
    await _store.writeString(
      _entriesKey,
      jsonEncode(
        updated
            .map(
              (LogEntryEntity item) => LogEntryRecord.fromEntity(item).toJson(),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> clear() {
    return _store.delete(_entriesKey);
  }
}
