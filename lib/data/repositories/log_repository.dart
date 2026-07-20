import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/log_entry_record.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

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
      final _LogsDecodeResult decoded = _decodeStoredLogs(raw);
      final List<LogEntryEntity> entries = decoded.entries;
      entries.sort(
        (LogEntryEntity a, LogEntryEntity b) =>
            b.timestamp.compareTo(a.timestamp),
      );
      return entries;
    } on FormatException catch (error) {
      Logger.error('Stored logs are corrupt.', error);
      throw StateError(
        'Log storage is corrupted. Refusing to treat it as empty history.',
      );
    }
  }

  Future<PagedResult<LogEntryEntity>> getLogsPage({
    String? cursor,
    int limit = 50,
  }) async {
    final List<LogEntryEntity> entries = await getLogs();
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : entries.indexWhere((LogEntryEntity entry) => entry.id == cursor) + 1;
    if (startIndex >= entries.length) {
      return const PagedResult<LogEntryEntity>(
        items: <LogEntryEntity>[],
        nextCursor: null,
      );
    }
    final List<LogEntryEntity> page = entries
        .skip(startIndex)
        .take(safeLimit)
        .toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < entries.length && page.isNotEmpty
        ? page.last.id
        : null;
    return PagedResult<LogEntryEntity>(items: page, nextCursor: nextCursor);
  }

  @override
  Future<void> addLog(LogEntryEntity entry) async {
    final String? raw = await _store.readString(_entriesKey);
    final _LogsDecodeResult decoded;
    try {
      decoded = raw == null || raw.trim().isEmpty
          ? const _LogsDecodeResult(entries: <LogEntryEntity>[])
          : _decodeStoredLogs(raw);
    } on FormatException {
      throw StateError(
        'Log storage is corrupted. Refusing to overwrite until repaired.',
      );
    }
    final List<LogEntryEntity> entries = decoded.entries;
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

  _LogsDecodeResult _decodeStoredLogs(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Log storage is not a list.');
    }
    final List<LogEntryEntity> entries = <LogEntryEntity>[];
    int malformedCount = 0;
    for (final Object? value in decoded) {
      if (value is! Map) {
        malformedCount++;
        continue;
      }
      try {
        final Map<String, dynamic> json = value.map(
          (dynamic key, dynamic item) => MapEntry(key.toString(), item),
        );
        entries.add(LogEntryRecord.fromJson(json).toEntity());
      } on FormatException catch (error) {
        malformedCount++;
        if (malformedCount == 1) {
          Logger.warn('Skipping malformed log entry: $error');
        }
      }
    }
    if (malformedCount > 1) {
      Logger.warn('Skipped $malformedCount malformed log entries while reading storage.');
    }
    return _LogsDecodeResult(entries: entries);
  }
}

class _LogsDecodeResult {
  const _LogsDecodeResult({required this.entries});

  final List<LogEntryEntity> entries;
}
