import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

class HabitRepository implements IHabitRepository {
  HabitRepository(this._storage, {this.scope});

  static const String _key = 'habit_records_v1';

  final HiveStorage<String> _storage;
  final AccountStorageScope? scope;

  @override
  Future<List<HabitEntity>> getHabits() async {
    _requireWritableScope();
    await _storage.open();
    final String? raw = _storage.get(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitEntity>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Daily Rhythm storage is not a list.');
    }
    final List<HabitEntity> habits = <HabitEntity>[];
    for (final Object? value in decoded) {
      if (value is! Map<dynamic, dynamic>) {
        throw const FormatException('Daily Rhythm record is not an object.');
      }
      final HabitEntity habit = HabitEntity.fromJson(
        value.map<String, dynamic>(
          (dynamic key, dynamic item) => MapEntry(key.toString(), item),
        ),
      );
      if (habit.id.isEmpty) {
        throw const FormatException('Daily Rhythm identity is invalid.');
      }
      habits.add(habit);
    }
    return habits;
  }

  @override
  Future<void> saveHabits(List<HabitEntity> habits) {
    _requireWritableScope();
    return _storage.put(
      _key,
      jsonEncode(
        habits.map((HabitEntity item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  void _requireWritableScope() {
    final AccountStorageScope? activeScope = scope;
    if (activeScope != null && !activeScope.isWritable) {
      throw StateError('Daily Rhythms require authenticated account storage.');
    }
  }
}
