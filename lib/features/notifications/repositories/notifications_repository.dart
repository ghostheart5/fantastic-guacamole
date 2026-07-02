import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/notification_scheduler.dart';

class NotificationsRepository {
  NotificationsRepository(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _scheduler.schedule(
      NotificationEntity(id: id, title: title, message: body, scheduledAt: at),
    );
  }

  Future<void> cancelNotification(String id) async {
    await _scheduler.cancel(id);
  }

  Future<void> cancelAll() async {
    await _scheduler.cancelAll();
  }
}
