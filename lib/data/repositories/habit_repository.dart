import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/habit_record.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

class HabitRepository implements IHabitRepository {
  HabitRepository(this._storage);

  static const String _key = 'habit_records_v1';

  final HiveStorage<String> _storage;

  @override
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

  @override
  Future<void> saveHabits(List<HabitRecord> habits) {
    return _storage.put(
      _key,
      jsonEncode(
        habits.map((HabitRecord item) => item.toJson()).toList(growable: false),
      ),
    );
  }
}
