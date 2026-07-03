import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalsProvider =
    NotifierProvider<GoalsNotifier, List<GoalEntity>>(GoalsNotifier.new);

class GoalsNotifier extends Notifier<List<GoalEntity>> {
  static const _key = 'goals_v2';
  static const _legacyKey = 'goals_v1';

  @override
  List<GoalEntity> build() {
    // Try v2 first, fall back to v1 migration
    final raw = SharedPrefsService.load(_key) ?? SharedPrefsService.load(_legacyKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => GoalEntity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final goal = GoalEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      createdAt: DateTime.now(),
      description: description?.trim().isEmpty ?? true ? null : description?.trim(),
      targetDate: targetDate,
    );
    state = [goal, ...state];
    await _persist();
  }

  Future<void> update(GoalEntity updated) async {
    state = state.map((g) => g.id == updated.id ? updated : g).toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    await SharedPrefsService.save(
      _key,
      jsonEncode(state.map((g) => g.toJson()).toList()),
    );
  }
}
