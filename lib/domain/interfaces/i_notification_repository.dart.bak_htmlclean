import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';

abstract class INotificationRepository {
  Future<List<NotificationEntity>> getNotifications();
  Future<void> scheduleNotification(NotificationEntity notification);
  Future<void> cancelNotification(String id);
  Future<void> markRead(String id);
  Future<void> delete(String id);
}
