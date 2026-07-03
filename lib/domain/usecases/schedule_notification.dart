import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/policies/notification_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';

class ScheduleNotification {
  ScheduleNotification(this.repository, {this.generateSiDecision});

  final INotificationRepository repository;
  final GenerateSiDecision? generateSiDecision;

  Future<void> call(NotificationEntity notification) async {
    NotificationEntity finalNotification = notification;

    final GenerateSiDecision? si = generateSiDecision;
    if (si != null) {
      final siDecision = await si('nudge user to work');
      final String adaptedMessage = siDecision.action.isNotEmpty
          ? siDecision.action
          : notification.message;
      finalNotification = NotificationEntity(
        id: notification.id,
        title: notification.title,
        message: adaptedMessage,
        scheduledAt: notification.scheduledAt,
        isEnabled: notification.isEnabled,
        isRead: notification.isRead,
      );
    }

    if (!NotificationPolicy.canSchedule(finalNotification)) {
      throw Exception('Notification cannot be scheduled');
    }
    await repository.scheduleNotification(finalNotification);
  }
}
