import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class PlanRepository implements IPlanRepository {
  PlanRepository(this._store);

  final HiveStorage<String> _store;

  @override
  Future<PlanEntity?> getPlan(DateTime date) async {
    await _store.open();
    final String? raw = _store.get(_dateKey(date));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _fromJson(decoded);
  }

  @override
  Future<void> savePlan(PlanEntity plan) async {
    await _store.put(_dateKey(plan.date), jsonEncode(_toJson(plan)));
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
