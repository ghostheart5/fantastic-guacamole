import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';

class GetNotifications {
  GetNotifications(this.repository);

  final INotificationRepository repository;

  Future<List<NotificationEntity>> call() {
    return repository.getNotifications();
  }
}
