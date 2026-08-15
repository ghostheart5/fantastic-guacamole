import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

abstract class INotificationRepository {
  Future<List<NotificationEntity>> getNotifications();
  Future<void> scheduleNotification(NotificationEntity notification);
  Future<void> cancelNotification(String id);
  Future<void> markRead(String id);
  Future<void> delete(String id);
}

/// Optional capability for producers that must register external ownership only
/// after the platform scheduler confirms a successful schedule.
abstract class SchedulingResultNotificationRepository
    implements INotificationRepository {
  Future<NotificationScheduleResult> scheduleNotificationWithResult(
    NotificationEntity notification,
  );
}
