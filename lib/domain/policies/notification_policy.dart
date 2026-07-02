import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';

class NotificationPolicy {
  static bool canSchedule(NotificationEntity notification, {DateTime? now}) {
    if (!notification.isEnabled) return false;
    final DateTime reference = now ?? DateTime.now();
    return notification.scheduledAt.isAfter(reference);
  }
}
