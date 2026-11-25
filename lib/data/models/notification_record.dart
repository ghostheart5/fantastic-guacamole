import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledAt,
    required this.isEnabled,
    required this.isRead,
    this.scheduleResult,
  });

  final String id;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final bool isEnabled;
  final bool isRead;

  /// Optional: absent in lists stored by older builds, and an unknown value
  /// reads as absent.
  final NotificationScheduleResult? scheduleResult;

  factory NotificationRecord.fromEntity(NotificationEntity entity) {
    return NotificationRecord(
      id: entity.id,
      title: entity.title,
      message: entity.message,
      scheduledAt: entity.scheduledAt,
      isEnabled: entity.isEnabled,
      isRead: entity.isRead,
      scheduleResult: entity.scheduleResult,
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
      scheduledAt: scheduledAt.toLocal(),
      isEnabled: requiredBool('isEnabled'),
      isRead: requiredBool('isRead'),
      scheduleResult: NotificationScheduleResult.values
          .asNameMap()[json['scheduleResult']],
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
      scheduleResult: scheduleResult,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'message': message,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    'isEnabled': isEnabled,
    'isRead': isRead,
    if (scheduleResult != null) 'scheduleResult': scheduleResult!.name,
  };
}
