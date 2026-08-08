import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Notifications
///
/// Resolved by notificationProvider. Blank-id guarded.
class CancelNotification {
  CancelNotification(this.repository);

  final INotificationRepository repository;

  Future<void> call(String id) {
    return repository.cancelNotification(InputGuard.id(id, 'id'));
  }
}
