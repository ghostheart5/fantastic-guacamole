import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:flutter/foundation.dart';

@immutable
class HabitRecord {
  const HabitRecord({
    required this.id,
    required this.title,
    this.active = true,
  });

  final String id;
  final String title;
  final bool active;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'active': active,
  };

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    return HabitRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
    );
  }
}

class HabitRepository {
  HabitRepository(this._storage, {this._syncDispatcher});

  static const String _key = 'habit_records_v1';

  final HiveStorage<String> _storage;
  final SyncMutationDispatcher? _syncDispatcher;

  Future<List<HabitRecord>> getHabits() async {
    await _storage.open();
    final String? raw = _storage.get(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitRecord>[];
    }
    final Object? decoded = jsonDecode(raw);
    final List<dynamic> list = decoded is List<dynamic>
        ? decoded
        : const <dynamic>[];
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> map) => HabitRecord.fromJson(
            map.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .where((HabitRecord record) => record.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveHabits(List<HabitRecord> habits) async {
    final List<HabitRecord> previous = await getHabits();
    await _storage.put(
      _key,
      jsonEncode(
        habits.map((HabitRecord item) => item.toJson()).toList(growable: false),
      ),
    );

    final Set<String> nextIds = habits
        .map((HabitRecord item) => item.id)
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> removedIds = previous
        .map((HabitRecord item) => item.id)
        .where((String id) => id.isNotEmpty && !nextIds.contains(id))
        .toSet();

    for (final HabitRecord habit in habits) {
      await _syncDispatcher?.enqueueUpsert(
        tableName: 'habits',
        recordId: habit.id,
        payload: <String, dynamic>{
          'id': habit.id,
          'title': habit.title,
          'active': habit.active,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_at': null,
        },
      );
    }

    for (final String removedId in removedIds) {
      await _syncDispatcher?.enqueueDelete(
        tableName: 'habits',
        recordId: removedId,
      );
    }
  }
}
