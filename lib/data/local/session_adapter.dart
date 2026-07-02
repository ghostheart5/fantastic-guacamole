import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/core/utils/json_utils.dart';

/// Converts raw JSON into SessionEntity and back.
class SessionAdapter {
  static SessionEntity fromJson(Map<String, dynamic> json) {
    final startedAt =
        DateTime.tryParse(JsonUtils.getString(json, 'startedAt')) ??
        DateTime.now();
    final endedAtRaw = json['endedAt'] as String?;
    final plannedMs = JsonUtils.getNum(
      json,
      'plannedDurationMs',
      fallback: 1500000,
    ).toInt();

    return SessionEntity(
      id: JsonUtils.getString(json, 'id', fallback: ''),
      taskId: JsonUtils.getString(json, 'taskId', fallback: ''),
      startedAt: startedAt,
      endedAt: endedAtRaw != null ? DateTime.tryParse(endedAtRaw) : null,
      plannedDuration: Duration(milliseconds: plannedMs),
    );
  }

  static List<SessionEntity> fromJsonList(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  static Map<String, dynamic> toJson(SessionEntity entity) {
    return {
      'id': entity.id,
      'taskId': entity.taskId,
      'startedAt': entity.startedAt.toIso8601String(),
      'endedAt': entity.endedAt?.toIso8601String(),
      'plannedDurationMs': entity.plannedDuration.inMilliseconds,
    };
  }
}
