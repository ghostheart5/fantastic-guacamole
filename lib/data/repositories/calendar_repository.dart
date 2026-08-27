// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';

class CalendarRepository implements ICalendarRepository {
  CalendarRepository(this._store);

  static const String _entriesKey = 'calendar_entries_v1';
  final SecureStore _store;

  @override
  Future<List<CalendarEntryEntity>> getEntries() async {
    final String? raw = await _store.readString(_entriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CalendarEntryEntity>[];
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <CalendarEntryEntity>[];
    }

    final List<CalendarEntryEntity> items = <CalendarEntryEntity>[];
    for (final Object? value in decoded) {
      if (value is! Map) {
        continue;
      }
      final Map<String, dynamic> json = value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
      final DateTime start =
          DateTime.tryParse((json['start'] as String?) ?? '') ?? DateTime.now();
      final DateTime end =
          DateTime.tryParse((json['end'] as String?) ?? '') ??
          start.add(const Duration(hours: 1));
      items.add(
        CalendarEntryEntity(
          id: (json['id'] as String?) ?? '',
          title: (json['title'] as String?) ?? 'Untitled',
          description: json['description'] as String?,
          start: start,
          end: end,
          taskId: json['taskId'] as String?,
          isCompleted: (json['isCompleted'] as bool?) ?? false,
        ),
      );
    }

    items.sort(
      (CalendarEntryEntity a, CalendarEntryEntity b) =>
          a.start.compareTo(b.start),
    );
    return items;
  }

  @override
  Future<void> saveEntry(CalendarEntryEntity entry) async {
    final List<CalendarEntryEntity> entries = await getEntries();
    final List<CalendarEntryEntity> updated = <CalendarEntryEntity>[
      entry,
      ...entries.where((CalendarEntryEntity item) => item.id != entry.id),
    ];
    await _store.writeString(
      _entriesKey,
      jsonEncode(updated.map(_toJson).toList(growable: false)),
    );
  }

  @override
  Future<void> removeEntry(String id) async {
    final List<CalendarEntryEntity> entries = await getEntries();
    final List<CalendarEntryEntity> updated = entries
        .where((CalendarEntryEntity item) => item.id != id)
        .toList();
    await _store.writeString(
      _entriesKey,
      jsonEncode(updated.map(_toJson).toList(growable: false)),
    );
  }

  Map<String, dynamic> _toJson(CalendarEntryEntity entry) {
    return <String, dynamic>{
      'id': entry.id,
      'title': entry.title,
      'description': entry.description,
      'start': entry.start.toIso8601String(),
      'end': entry.end.toIso8601String(),
      'taskId': entry.taskId,
      'isCompleted': entry.isCompleted,
    };
  }
}
