import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';

class InsightRepository implements IInsightRepository {
  InsightRepository(this._store);

  static const String _key = 'insights_v1';

  final SharedPrefsStore _store;

  @override
  Future<List<InsightEntity>> getInsights() async {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <InsightEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().map(_fromJson).toList(growable: false);
    } catch (_) {
      return const <InsightEntity>[];
    }
  }

  @override
  Future<void> saveInsight(InsightEntity insight) async {
    final List<InsightEntity> existing = (await getInsights()).toList(growable: true);
    final int index = existing.indexWhere((InsightEntity item) => item.id == insight.id);
    if (index >= 0) {
      existing[index] = insight;
    } else {
      existing.insert(0, insight);
    }
    await _store.save(_key, jsonEncode(existing.map(_toJson).toList(growable: false)));
  }

  @override
  Future<bool> exists(String id) async {
    final List<InsightEntity> insights = await getInsights();
    return insights.any((InsightEntity item) => item.id == id);
  }

  @override
  Future<void> removeInsight(String id) async {
    final List<InsightEntity> next = (await getInsights())
        .where((InsightEntity item) => item.id != id)
        .toList(growable: false);
    await _store.save(_key, jsonEncode(next.map(_toJson).toList(growable: false)));
  }

  @override
  Future<List<InsightEntity>> searchInsights(String query) async {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return getInsights();
    }
    final List<InsightEntity> insights = await getInsights();
    return insights.where((InsightEntity item) => item.matches(normalized)).toList(growable: false);
  }

  static InsightEntity _fromJson(Map<String, dynamic> json) {
    return InsightEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Insight',
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).cast<String>(),
      action: json['action'] as String?,
    );
  }

  static Map<String, dynamic> _toJson(InsightEntity insight) {
    return <String, dynamic>{
      'id': insight.id,
      'title': insight.title,
      'summary': insight.summary,
      'createdAt': insight.createdAt.toIso8601String(),
      'tags': insight.tags,
      'action': insight.action,
    };
  }
}
