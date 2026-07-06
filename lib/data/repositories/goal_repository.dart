import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalRepository implements IGoalRepository {
  GoalRepository(this._store);

  static const String _key = 'goals_v2';
  static const String _legacyKey = 'goals_v1';

  final SharedPrefsStore _store;

  @override
  List<GoalEntity> getGoals() {
    final String? raw = _store.load(_key) ?? _store.load(_legacyKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <GoalEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(GoalEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <GoalEntity>[];
    }
  }

  @override
  Future<void> saveGoal(GoalEntity goal) {
    final List<GoalEntity> existing = getGoals().toList(growable: true);
    final int index = existing.indexWhere(
      (GoalEntity item) => item.id == goal.id,
    );
    if (index >= 0) {
      existing[index] = goal;
    } else {
      existing.insert(0, goal);
    }
    return saveGoals(existing);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) {
    return _store.save(
      _key,
      jsonEncode(goals.map((GoalEntity g) => g.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteGoal(String id) {
    final List<GoalEntity> next = getGoals()
        .where((GoalEntity goal) => goal.id != id)
        .toList(growable: false);
    return saveGoals(next);
  }
}
