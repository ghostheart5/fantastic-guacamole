import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';

sealed class NotificationState {
  const NotificationState();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationData extends NotificationState {
  final List<NotificationEntity> notifications;
  const NotificationData(this.notifications);
}

class NotificationEmpty extends NotificationState {
  const NotificationEmpty();
}

class NotificationError extends NotificationState {
  final Object error;
  const NotificationError(this.error);
}
