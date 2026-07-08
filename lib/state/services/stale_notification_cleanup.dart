import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';

class StaleNotificationCleanup {
  const StaleNotificationCleanup({
    required this._repository,
    required this._retentionPolicy,
  });

  final INotificationRepository _repository;
  final RetentionPolicy _retentionPolicy;

  Future<int> run() async {
    final notifications = await _repository.getNotifications();
    int removed = 0;

    for (final notification in notifications) {
      final bool stale = _retentionPolicy.isNotificationStale(
        notification.scheduledAt,
      );
      if (!stale) {
        continue;
      }

      if (notification.isRead || !notification.isEnabled) {
        await _repository.delete(notification.id);
        removed++;
      }
    }

    return removed;
  }
}
