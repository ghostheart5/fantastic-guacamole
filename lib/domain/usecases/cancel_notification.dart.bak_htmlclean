import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';

class CancelNotification {
  CancelNotification(this.repository);

  final INotificationRepository repository;

  Future<void> call(String id) {
    return repository.cancelNotification(id);
  }
}
