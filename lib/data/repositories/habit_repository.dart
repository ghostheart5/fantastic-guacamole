import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

class HabitRepository implements IHabitRepository {
  HabitRepository(this._storage);

  static const String _key = 'habit_records_v1';

  final HiveStorage<String> _storage;

  @override
  Future<List<HabitEntity>> getHabits() async {
    await _storage.open();
    final String? raw = _storage.get(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitEntity>[];
    }
    final Object? decoded = jsonDecode(raw);
    final List<dynamic> list = decoded is List<dynamic>
        ? decoded
        : const <dynamic>[];
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> map) => HabitEntity.fromJson(
            map.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .where((HabitEntity record) => record.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveHabits(List<HabitEntity> habits) {
    return _storage.put(
      _key,
      jsonEncode(
        habits.map((HabitEntity item) => item.toJson()).toList(growable: false),
      ),
    );
  }
}
