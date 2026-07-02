import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/policies/notification_policy.dart';

class ScheduleNotification {
  ScheduleNotification(this.repository);

  final INotificationRepository repository;

  Future<void> call(NotificationEntity notification) async {
    if (!NotificationPolicy.canSchedule(notification)) {
      throw Exception('Notification cannot be scheduled');
    }
    await repository.scheduleNotification(notification);
  }
}
