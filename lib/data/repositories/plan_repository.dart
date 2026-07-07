import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class PlanRepository implements IPlanRepository {
  PlanRepository(this._store);

  static const String _key = 'plans_v1';

  final SharedPrefsStore _store;

  @override
  Future<PlanEntity?> getPlan(DateTime date) async {
    final Map<String, dynamic> plans = _loadPlans();
    final String key = _dateKey(date);
    final Object? raw = plans[key];
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return _fromJson(raw);
  }

  @override
  Future<void> savePlan(PlanEntity plan) async {
    final Map<String, dynamic> plans = _loadPlans();
    plans[_dateKey(plan.date)] = _toJson(plan);
    await _store.save(_key, jsonEncode(plans));
  }

  Map<String, dynamic> _loadPlans() {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed persisted plans and return an empty map.
    }
    return <String, dynamic>{};
  }

  static String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static PlanEntity _fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawBlocks =
        json['blocks'] as List<dynamic>? ?? const <dynamic>[];
    return PlanEntity(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> block) => TimeBlock(
              id: block['id'] as String? ?? '',
              taskId: block['taskId'] as String? ?? '',
              title: block['title'] as String? ?? 'Untitled',
              start:
                  DateTime.tryParse(block['start'] as String? ?? '') ??
                  DateTime.now(),
              end:
                  DateTime.tryParse(block['end'] as String? ?? '') ??
                  DateTime.now().add(const Duration(minutes: 30)),
              completed: block['completed'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _toJson(PlanEntity plan) {
    return <String, dynamic>{
      'id': plan.id,
      'date': plan.date.toIso8601String(),
      'updatedAt': (plan.updatedAt ?? DateTime.now()).toIso8601String(),
      'blocks': plan.blocks
          .map(
            (TimeBlock block) => <String, dynamic>{
              'id': block.id,
              'taskId': block.taskId,
              'title': block.title,
              'start': block.start.toIso8601String(),
              'end': block.end.toIso8601String(),
              'completed': block.completed,
            },
          )
          .toList(growable: false),
    };
  }
}
