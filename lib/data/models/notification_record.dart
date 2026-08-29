import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledAt,
    required this.isEnabled,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final bool isEnabled;
  final bool isRead;

  factory NotificationRecord.fromEntity(NotificationEntity entity) {
    return NotificationRecord(
      id: entity.id,
      title: entity.title,
      message: entity.message,
      scheduledAt: entity.scheduledAt,
      isEnabled: entity.isEnabled,
      isRead: entity.isRead,
    );
  }

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final String value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('Invalid notification $key.');
      }
      return value;
    }

    bool requiredBool(String key) {
      final Object? value = json[key];
      if (value is! bool) {
        throw FormatException('Invalid notification $key.');
      }
      return value;
    }

    final DateTime? scheduledAt = DateTime.tryParse(
      json['scheduledAt']?.toString() ?? '',
    );
    if (scheduledAt == null) {
      throw const FormatException('Invalid notification timestamp.');
    }
    return NotificationRecord(
      id: requiredText('id'),
      title: requiredText('title'),
      message: requiredText('message'),
      scheduledAt: scheduledAt,
      isEnabled: requiredBool('isEnabled'),
      isRead: requiredBool('isRead'),
    );
  }

  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      title: title,
      message: message,
      scheduledAt: scheduledAt,
      isEnabled: isEnabled,
      isRead: isRead,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'message': message,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    'isEnabled': isEnabled,
    'isRead': isRead,
  };
}
