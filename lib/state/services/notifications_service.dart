import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

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

  /// Schedules an in-app ledger entry and returns the platform scheduling
  /// outcome. Callers that own an external schedule must use this before
  /// registering platform ownership.
  Future<NotificationScheduleResult> scheduleWithResult({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) {
    final INotificationRepository repository = _repository;
    if (repository is! SchedulingResultNotificationRepository) {
      throw StateError(
        'Notification repository does not expose scheduling results.',
      );
    }
    return repository.scheduleNotificationWithResult(
      NotificationEntity(id: id, title: title, message: body, scheduledAt: at),
    );
  }

  Future<void> cancel(String id) async {
    await _repository.cancelNotification(id);
  }

  Future<void> cancelAll() async {
    final List<NotificationEntity> notifications = await _repository
        .getNotifications();
    for (final NotificationEntity notification in notifications) {
      await _repository.cancelNotification(notification.id);
    }
  }
}
