import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';

class NotificationsService {
  NotificationsService(this._repository);

  final INotificationRepository _repository;

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _repository.scheduleNotification(
      NotificationEntity(id: id, title: title, message: body, scheduledAt: at),
    );
  }

  Future<void> cancel(String id) async {
    await _repository.cancelNotification(id);
  }

  /// Cancels every listed notification whose id matches [test].
  Future<void> cancelWhere(bool Function(String id) test) async {
    final List<NotificationEntity> notifications = await _repository
        .getNotifications();
    for (final NotificationEntity notification in notifications) {
      if (test(notification.id)) {
        await _repository.cancelNotification(notification.id);
      }
    }
  }

  Future<void> cancelAll() async {
    final List<NotificationEntity> notifications = await _repository
        .getNotifications();
    for (final NotificationEntity notification in notifications) {
      await _repository.cancelNotification(notification.id);
    }
  }
}
