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
    final DateTime? scheduledAt = DateTime.tryParse(
      json['scheduledAt']?.toString() ?? '',
    );
    if (scheduledAt == null) {
      throw const FormatException('Invalid notification timestamp.');
    }
    return NotificationRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      scheduledAt: scheduledAt,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isRead: json['isRead'] as bool? ?? false,
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
