import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/core/utils/json_utils.dart';

/// Converts raw JSON into InsightEntity and back.
class InsightAdapter {
  static InsightEntity fromJson(Map<String, dynamic> json) {
    return InsightEntity(
      id: JsonUtils.getString(json, 'id', fallback: ''),
      title: JsonUtils.getString(json, 'title', fallback: 'Insight'),
      summary: JsonUtils.getString(json, 'summary', fallback: ''),
      createdAt:
          DateTime.tryParse(JsonUtils.getString(json, 'createdAt')) ??
          DateTime.now(),
      tags:
          (json['tags'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
      action: json['action'] as String?,
    );
  }

  static List<InsightEntity> fromJsonList(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  static Map<String, dynamic> toJson(InsightEntity entity) {
    return {
      'id': entity.id,
      'title': entity.title,
      'summary': entity.summary,
      'createdAt': entity.createdAt.toIso8601String(),
      'tags': entity.tags,
      'action': entity.action,
    };
  }
}
